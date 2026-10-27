package com.myaaptha.domain.ai;

import com.myaaptha.platform.state.EphemeralState;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.Principal;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.Semaphore;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/ai/help")
public class HelpChatController {
  public record Turn(@NotBlank @Pattern(regexp="user|assistant") String role,
      @NotBlank @Size(max=5000) String content) {}
  public record Request(@NotBlank @Size(max=1200) String message,
      @Size(max=6) List<@NotNull @Valid Turn> history, boolean useAi, @Size(max=36) String retryOf) {
    public Request(String message,List<Turn> history,boolean useAi){this(message,history,useAi,null);}
  }
  public record Source(String id, String title, String path, String content) {}
  public record Reply(String answer, String mode, String notice, List<Source> sources, String exchangeId, String tier, String model) {
    public Reply(String answer,String mode,String notice,List<Source> sources){this(answer,mode,notice,sources,null,"BASE","");}
  }
  public record AdminSettings(boolean enhancedEnabled) {}
  public record Publish(@NotBlank @Size(max=1200) String question, @NotBlank @Size(max=5000) String answer,
      @NotEmpty @Size(max=10) List<@NotBlank @Size(max=80) String> sourceIds, @AssertTrue boolean confirmedPublic) {}
  private final HelpKnowledge knowledge;
  private final HelpChatProvider provider;
  private final AiPreferenceService preferences;
  private final EphemeralState state;
  private final int globalLimit;
  private final HelpAnswerMemory memory;
  private final String enhancedModel;
  private final Semaphore inFlight=new Semaphore(4);
  public HelpChatController(HelpKnowledge knowledge, HelpChatProvider provider,
      AiPreferenceService preferences, EphemeralState state,
      @Value("${myaaptha.help-ai.requests-per-minute:60}") int globalLimit, HelpAnswerMemory memory,
      @Value("${myaaptha.help-ai.enhanced-model:gpt-4.1}") String enhancedModel) {
    this.knowledge=knowledge;this.provider=provider;this.preferences=preferences;this.state=state;this.globalLimit=globalLimit;this.memory=memory;this.enhancedModel=enhancedModel;
  }
  @GetMapping
  public Map<String,Object> status(org.springframework.security.core.Authentication auth) {
    return Map.of("aiConfigured",provider.configured(),"enhancedEnabled",memory.enhancedEnabled(),
        "canManage",auth!=null && auth.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("ROLE_ADMIN")),
        "baseModel",provider.model(),"enhancedModel",enhancedModel,"questions",List.of(
        "Is MyAaptha free?","How do I view profile contact details?",
        "How do I add new relations?","How do I message relations horizontally or vertically?"));
  }
  @PostMapping("/chat")
  public Reply chat(Principal principal, @Valid @RequestBody Request request) {
    List<Turn> history=request.history()==null?List.of():request.history();
    if(history.stream().mapToInt(t->t.content().length()).sum()>12000)
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Please start a new chat; the conversation is too long");
    long user=Long.parseLong(principal.getName());
    int days=preferences.get(user).activityRetentionDays();
    String question=request.message();
    boolean enhanced=request.retryOf()!=null;
    if(enhanced) {
      if(!request.useAi() || !memory.enhancedEnabled())
        throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Stronger-model retries are disabled by the administrator");
      var original=memory.owned(user,request.retryOf(),days);
      if(!"BASE".equals(original.reply().tier()) || "HELP".equals(original.reply().mode()))
        throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Request a base AI answer before trying the stronger model");
      question=original.question();history=original.history();
    }
    if(request.useAi())preferences.requireEnabled(user);
    String model=enhanced?enhancedModel:provider.model();
    String tier=enhanced?"ENHANCED":"BASE";
    String key=memory.key(question,history,model);
    Reply reply;
    int input=0,output=0;
    var shared=!enhanced && history.isEmpty()?memory.shared(question):Optional.<HelpAnswerMemory.Shared>empty();
    var cached=request.useAi()?memory.find(user,key,days):Optional.<Reply>empty();
    if(shared.isPresent()) {
      // A copy in personal history must not outlive revocation of a shared answer.
      key=memory.key(question,history,"REVIEWED");
      var value=shared.get();
      reply=new Reply(value.answer(),"CACHE","Reviewed application answer. No AI credits used.",
          knowledge.all().stream().filter(a->value.sourceIds().contains(a.id())).map(this::source).toList(),null,tier,model);
    } else if(cached.isPresent()) {
      var value=cached.get();
      reply=new Reply(value.answer(),"CACHE","Saved answer. No AI credits used.",value.sources(),null,tier,model);
    } else if(!request.useAi()) reply=help(question,"Answers from MyAaptha help articles.");
    else if(!provider.configured()) reply=help(question,"OpenAI is not configured yet. Showing MyAaptha help articles.");
    else {
      boolean allowed=false;
      try {
        allowed=state.increment("help-chat:user:"+user,Duration.ofMinutes(1))<=10 &&
            state.increment("help-chat:global",Duration.ofMinutes(1))<=globalLimit &&
            (!enhanced || state.increment("help-chat:enhanced:"+user,Duration.ofDays(1))<=2);
      } catch(RuntimeException ignored) { }
      if(!allowed || !inFlight.tryAcquire()) reply=help(question,"AI usage limit reached or service busy. Application help is available below.");
      else try {
        // Retrieve a small relevant set rather than sending the entire manual on every call.
        var articles=knowledge.search(question);
        if(articles.isEmpty() && !history.isEmpty())articles=knowledge.search(history.getLast().content());
        if(articles.isEmpty()) reply=help(question,"Try a question about MyAaptha features.");
        else {
          var result=enhanced?provider.answer(question,history,articles,model):provider.answer(question,history,articles);
          input=result.inputTokens();output=result.outputTokens();
          var sources=articles.stream().filter(a->result.sourceIds().contains(a.id())).map(this::source).toList();
          reply=new Reply(sources.isEmpty()?"I cannot confirm that from MyAaptha's documented help. Ask about profiles, relationships, broadcasts, messaging or account settings.":result.answer(),"AI","",sources,null,tier,model);
        }
      } catch(InterruptedException e) {
        Thread.currentThread().interrupt();reply=help(question,"AI was interrupted. Showing application help.");
      } catch(Exception e) {reply=help(question,"AI is temporarily unavailable. Showing application help.");}
      finally {inFlight.release();}
    }
    if(!"AI".equals(reply.mode()) && !"CACHE".equals(reply.mode()))
      reply=new Reply(reply.answer(),reply.mode(),reply.notice(),reply.sources(),null,tier,model);
    return memory.save(user,key,question,history,reply,days,input,output);
  }
  @DeleteMapping("/history") public void clear(Principal principal) {memory.clear(Long.parseLong(principal.getName()));}
  @PutMapping("/admin/settings") public AdminSettings settings(@Valid @RequestBody AdminSettings value) {
    memory.enhancedEnabled(value.enhancedEnabled());return value;
  }
  @PostMapping("/admin/answers") public void publish(Principal principal,@Valid @RequestBody Publish value) {
    if(value.sourceIds().stream().anyMatch(id->knowledge.all().stream().noneMatch(a->a.id().equals(id))))
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose valid help sources");
    memory.publish(Long.parseLong(principal.getName()),new HelpAnswerMemory.Shared(value.question(),value.answer(),value.sourceIds()));
  }
  @DeleteMapping("/admin/answers") public void clearShared(){memory.clearShared();}
  private Reply help(String question,String notice) {
    var matches=knowledge.search(question);
    String answer=matches.isEmpty()?"I cannot find that in MyAaptha help. Ask about pricing, profiles, adding relations or sending broadcasts.":
        String.join("\n\n",matches.stream().map(a->a.title()+"\n"+a.content()).toList());
    return new Reply(answer,"HELP",notice,matches.stream().map(this::source).toList());
  }
  private Source source(HelpKnowledge.Article article) { return new Source(article.id(),article.title(),article.path(),article.content()); }
}

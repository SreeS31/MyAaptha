package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.platform.state.EphemeralState;
import java.net.http.*;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

class HelpChatTest {
  ObjectMapper json=new ObjectMapper();
  HelpKnowledge knowledge;
  HelpChatProvider provider=mock(HelpChatProvider.class);
  AiPreferenceService preferences=mock(AiPreferenceService.class);
  EphemeralState state=mock(EphemeralState.class);
  HelpChatController controller;
  HelpAnswerMemory memory=mock(HelpAnswerMemory.class);
  @BeforeEach void setup() throws Exception {
    knowledge=new HelpKnowledge(json);
    when(preferences.get(42L)).thenReturn(new AiPreferenceService.AiPreferenceDto(42L,true,false,false,90,null));
    when(provider.model()).thenReturn("gpt-4.1-mini");
    when(memory.save(anyLong(),nullable(String.class),anyString(),anyList(),any(),anyInt(),anyInt(),anyInt())).thenAnswer(i->i.getArgument(4));
    controller=new HelpChatController(knowledge,provider,preferences,state,60,memory,"gpt-4.1");
  }
  HelpChatController.Reply ask(String message,boolean useAi) {
    return controller.chat(()->"42",new HelpChatController.Request(message,List.of(),useAi));
  }
  @Test void documentedQuestionsHaveCorrectSourcesWithoutProvider() {
    assertEquals("pricing",knowledge.search("Is this website free or not?").getFirst().id());
    assertEquals("contacts",knowledge.search("How to view profile contact details?").getFirst().id());
    assertEquals("relations",knowledge.search("How to add new relations?").getFirst().id());
    assertEquals("broadcast",knowledge.search("send message entire relations vertically horizantally").getFirst().id());
    assertTrue(ask("Is this website free?",false).answer().contains("free for all users"));
    assertTrue(ask("horizontal broadcast",false).answer().contains("not every relation"));
    verify(provider,never()).configured();verifyNoInteractions(state);
  }
  @Test void chatManagementAnswersComeFromCurrentApplicationInstructions() {
    var reply=ask("archive mute forward unread",false);
    assertTrue(reply.sources().stream().anyMatch(source->"chat-management".equals(source.id())));
    assertTrue(reply.answer().contains("does not undo read receipts"));
    verify(provider,never()).configured();
  }
  @Test void unknownQuestionDoesNotInventAnAnswer() {
    var answer=ask("quantum asteroid propulsion",false);
    assertTrue(answer.sources().isEmpty());assertTrue(answer.answer().contains("cannot find"));
  }
  @Test void unconfiguredProviderIsExplicitlyHelpOnly() {
    var reply=ask("pricing",true);
    assertEquals("HELP",reply.mode());assertTrue(reply.notice().contains("not configured"));
  }
  @Test void disabledAiStopsProviderCall() {
    doThrow(new ResponseStatusException(HttpStatus.FORBIDDEN)).when(preferences).requireEnabled(42L);
    assertThrows(ResponseStatusException.class,()->ask("pricing",true));verify(provider,never()).configured();
  }
  @Test void providerFailureAndRateLimitFallBackToArticles() throws Exception {
    when(provider.configured()).thenReturn(true);
    when(provider.answer(anyString(),anyList(),anyList())).thenThrow(new IllegalStateException("secret provider error"));
    var reply=ask("pricing",true);
    assertEquals("HELP",reply.mode());assertFalse(reply.notice().contains("secret"));
    reset(provider);when(provider.configured()).thenReturn(true);
    when(state.increment(eq("help-chat:user:42"),any())).thenReturn(11L);
    assertEquals("HELP",ask("pricing",true).mode());
    verify(provider,never()).answer(anyString(),anyList(),anyList());
  }
  @Test void citationsAreResolvedFromServerKnowledge() throws Exception {
    when(provider.configured()).thenReturn(true);
    when(provider.answer(anyString(),anyList(),anyList())).thenReturn(new HelpChatProvider.Result("MyAaptha is free.",List.of("pricing")));
    var reply=ask("pricing",true);
    assertEquals("AI",reply.mode());assertEquals("/help",reply.sources().getFirst().path());
    when(provider.answer(anyString(),anyList(),anyList())).thenReturn(new HelpChatProvider.Result("Invented fact",List.of()));
    assertTrue(ask("pricing",true).answer().contains("cannot confirm"));
  }
  @Test void oversizedConversationIsRejectedBeforeProvider() {
    var history=List.of(new HelpChatController.Turn("user","x".repeat(5000)),new HelpChatController.Turn("assistant","x".repeat(5000)),new HelpChatController.Turn("user","x".repeat(5000)));
    assertThrows(ResponseStatusException.class,()->controller.chat(()->"42",new HelpChatController.Request("help",history,true)));
    verify(provider,never()).configured();
  }
  @Test void providerUsesResponsesAndValidatesOutput() throws Exception {
    HttpClient http=mock(HttpClient.class);
    @SuppressWarnings("unchecked") HttpResponse<String> response=mock(HttpResponse.class);
    when(http.send(any(HttpRequest.class),org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any())).thenReturn(response);
    when(response.statusCode()).thenReturn(200);
    var answer=json.writeValueAsString(Map.of("answer","MyAaptha is free for all users.","sourceIds",List.of("pricing")));
    when(response.body()).thenReturn(json.writeValueAsString(Map.of("status","completed","output",List.of(Map.of("content",List.of(Map.of("type","output_text","text",answer)))))));
    var real=new HelpChatProvider(json,"test-only-key","gpt-4.1-mini",http);
    assertEquals(List.of("pricing"),real.answer("free?",List.of(),knowledge.all()).sourceIds());
    var capture=ArgumentCaptor.forClass(HttpRequest.class);
    verify(http).send(capture.capture(),org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any());
    assertEquals("https://api.openai.com/v1/responses",capture.getValue().uri().toString());
    assertEquals(20,capture.getValue().timeout().orElseThrow().toSeconds());
    var body=new java.util.concurrent.CompletableFuture<String>();
    capture.getValue().bodyPublisher().orElseThrow().subscribe(new java.util.concurrent.Flow.Subscriber<java.nio.ByteBuffer>() {
      final java.io.ByteArrayOutputStream bytes=new java.io.ByteArrayOutputStream();
      public void onSubscribe(java.util.concurrent.Flow.Subscription subscription){subscription.request(Long.MAX_VALUE);}
      public void onNext(java.nio.ByteBuffer value){byte[] chunk=new byte[value.remaining()];value.get(chunk);bytes.writeBytes(chunk);}
      public void onError(Throwable failure){body.completeExceptionally(failure);}
      public void onComplete(){body.complete(bytes.toString(java.nio.charset.StandardCharsets.UTF_8));}
    });
    var payload=json.readTree(body.get(5,java.util.concurrent.TimeUnit.SECONDS));
    assertFalse(payload.get("store").asBoolean());
    assertEquals(650,payload.get("max_output_tokens").asInt());
    assertEquals("json_schema",payload.path("text").path("format").path("type").asText());
    assertTrue(payload.get("instructions").asText().contains("approved articles"));
    String invalid=json.writeValueAsString(Map.of("answer","Made-up source","sourceIds",List.of("https://untrusted.invalid")));
    when(response.body()).thenReturn(json.writeValueAsString(Map.of("status","completed","output",List.of(Map.of("content",List.of(Map.of("type","output_text","text",invalid)))))));
    assertThrows(IllegalStateException.class,()->real.answer("free?",List.of(),knowledge.all()));
    when(response.body()).thenReturn("{\"status\":\"incomplete\",\"output\":[]}");
    assertThrows(IllegalStateException.class,()->real.answer("free?",List.of(),knowledge.all()));
    when(response.statusCode()).thenReturn(429);
    assertThrows(IllegalStateException.class,()->real.answer("free?",List.of(),knowledge.all()));
  }
}

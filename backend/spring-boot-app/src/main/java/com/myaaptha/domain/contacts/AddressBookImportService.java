package com.myaaptha.domain.contacts;

import com.myaaptha.domain.ai.AiPreferenceService;
import com.myaaptha.domain.contacts.AddressBookController.ContactInput;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class AddressBookImportService {
  private final AddressBookService book;
  private final AddressBookCircleService circles;
  private final AiPreferenceService preferences;
  private final RestClient ai;
  public AddressBookImportService(AddressBookService book,AddressBookCircleService circles,AiPreferenceService preferences,RestClient.Builder builder,@Value("${myaaptha.ai.base-url:http://localhost:8081/api/v1}") String base){
    this.book=book;this.circles=circles;this.preferences=preferences;
    var factory=new SimpleClientHttpRequestFactory();factory.setConnectTimeout(3000);factory.setReadTimeout(10000);
    ai=builder.requestFactory(factory).baseUrl(base).build();
  }
  public record Outcome(int added,int updated,int unchanged,long total,int circlesCreated,int contactsOrganized,String organizationMessage){}
  public record ReviewedOutcome(int added,int updated,int unchanged,int skipped,long total,String organizationMessage){}
  public static ContactInput usable(ContactInput input){
    var phones=(input.phones()==null?List.<String>of():input.phones()).stream()
        .flatMap(p->Arrays.stream(p.split(" ::: |[;,]"))).map(String::trim)
        .map(p->p.replaceFirst("(?i)^tel:","").replaceAll("[ ()\\-.]",""))
        .filter(p->p.matches("\\+?[0-9]{7,15}")).distinct().limit(20).toList();
    var emails=(input.emails()==null?List.<String>of():input.emails()).stream().map(String::trim)
        .filter(e->e.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")).distinct().toList();
    return new ContactInput(input.displayName(),phones,emails,input.organization(),input.groups());
  }
  @org.springframework.transaction.annotation.Transactional
  public ReviewedOutcome saveReviewed(long owner,List<AddressBookController.ReviewedContact> input,String source){
    int added=0,updated=0,unchanged=0,skipped=0;long total=book.list(owner,0,1,"",null).total();
    for(var row:input){
      var contact=usable(row.contact());if(contact.phones().isEmpty()){skipped++;continue;}
      var saved=book.save(owner,List.of(contact),source);
      added+=saved.added();updated+=saved.updated();unchanged+=saved.unchanged();total=saved.total();
      for(long id:saved.contactIds()){
        circles.organize(owner,List.of(new AddressBookCircleService.Assignment(id,row.circleNames())));
        circles.markReviewed(owner,id);
      }
    }
    return new ReviewedOutcome(added,updated,unchanged,skipped,total,"Saved your reviewed private contact selections. No invitations or relationships were created.");
  }
  public Outcome save(long owner,List<ContactInput> input,String source,boolean organize){
    input=input.stream().map(AddressBookImportService::usable).filter(c->!c.phones().isEmpty()).toList();
    if(input.isEmpty())return new Outcome(0,0,0,book.list(owner,0,1,"",null).total(),0,0,"Skipped contacts without usable phone numbers.");
    var saved=book.save(owner,input,source);int created=0,organized=0;String message="";
    if(organize){
      var settings=preferences.get(owner);
      if(!settings.aiEnabled()||!settings.allowSensitiveData())message="Contacts saved. Enable sensitive-data AI processing in AI controls, then reimport to organize circles.";
      else try{
        var contacts=book.entries(owner,saved.contactIds());
        // Only names, organizations and labels are needed for grouping; never send phone/email details.
        var payload=contacts.stream().map(c->Map.of("contact_key",Long.toString(c.id()),"display_name",c.displayName(),"organization",c.organization(),"labels",c.groups())).toList();
        var response=ai.post().uri("/contacts/organize").body(Map.of("consent",true,"contacts",payload)).retrieve().body(Suggestion[].class);
        Set<Long> allowed=new HashSet<>(saved.contactIds());var assignments=new ArrayList<AddressBookCircleService.Assignment>();
        if(response==null||response.length!=contacts.size())throw new IllegalStateException("Incomplete contact suggestions");
        for(var suggestion:response){long id=Long.parseLong(suggestion.contact_key());if(!allowed.remove(id))throw new IllegalStateException("Invalid contact suggestion");
          var names=suggestion.suggested_circles();if(names==null||names.size()>20)throw new IllegalStateException("Invalid circle suggestions");
          assignments.add(new AddressBookCircleService.Assignment(id,names));
        }
        var result=circles.organize(owner,assignments);created=result.circlesCreated();organized=result.contactsOrganized();
        message="Contacts saved and organized into private circle lists. Review the groupings; imported contacts are not messaging members.";
      }catch(Exception unavailable){message="Contacts saved, but automatic circle organization could not finish. Reimport to retry or assign circles manually.";}
    }
    return new Outcome(saved.added(),saved.updated(),saved.unchanged(),saved.total(),created,organized,message);
  }
  @com.fasterxml.jackson.annotation.JsonIgnoreProperties(ignoreUnknown=true)
  public record Suggestion(String contact_key,List<String> suggested_circles){}
}

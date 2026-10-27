package com.myaaptha.domain.contacts;

import com.myaaptha.domain.network.NetworkService;
import com.myaaptha.domain.network.dto.CreateNetworkCircleRequest;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AddressBookCircleService {
  private final JdbcTemplate jdbc;
  private final NetworkService network;
  public AddressBookCircleService(JdbcTemplate jdbc,NetworkService network){this.jdbc=jdbc;this.network=network;}
  public record Circle(long id,String name,long privateContactCount){}
  public record Assignment(long contactId,List<String> names){}
  public record Organized(int circlesCreated,int contactsOrganized){}
  public List<Circle> list(long owner){return jdbc.query("SELECT c.id,c.name,COUNT(a.id) AS contacts FROM circles c LEFT JOIN address_book_circle_contacts cc ON cc.circle_id=c.id LEFT JOIN address_book_contacts a ON a.id=cc.contact_id AND a.user_id=? WHERE c.owner_user_id=? GROUP BY c.id,c.name ORDER BY c.name,c.id",(rs,n)->new Circle(rs.getLong(1),rs.getString(2),rs.getLong(3)),owner,owner);}
  @Transactional
  public Organized organize(long owner,List<Assignment> assignments){
    lock(owner);var existing=list(owner);Map<String,Long> byName=new HashMap<>();existing.forEach(c->byName.putIfAbsent(key(c.name()),c.id()));
    Set<String> proposed=new HashSet<>();for(var a:assignments)for(String name:a.names())proposed.add(key(name));
    if(existing.size()+proposed.stream().filter(n->!byName.containsKey(n)).count()>500)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Automatic organization supports up to 500 owned circles. Assign contacts manually to existing circles.");
    int created=0,organized=0;
    for(var assignment:assignments){
      requireContact(owner,assignment.contactId());boolean assigned=false;
      if(Boolean.TRUE.equals(jdbc.queryForObject("SELECT circles_reviewed FROM address_book_contacts WHERE id=?",Boolean.class,assignment.contactId())))continue;
      for(String raw:assignment.names()){
        String name=raw.trim().replaceAll("\\s+"," ");if(name.isEmpty()||name.length()>100||name.chars().anyMatch(Character::isISOControl))continue;
        Long circle=byName.get(key(name));
        if(circle==null){circle=network.createCircle(owner,new CreateNetworkCircleRequest(name,"Automatically organized private contacts. Only explicitly invited members can join conversations.")).id();byName.put(key(name),circle);created++;}
        if(jdbc.queryForObject("SELECT COUNT(*) FROM address_book_circle_contacts WHERE contact_id=? AND circle_id=?",Long.class,assignment.contactId(),circle)==0)jdbc.update("INSERT INTO address_book_circle_contacts(contact_id,circle_id) VALUES (?,?)",assignment.contactId(),circle);
        assigned=true;
      }
      if(assigned)organized++;
    }
    return new Organized(created,organized);
  }
  @Transactional public void assign(long owner,long contact,List<Long> circleIds){
    lock(owner);requireContact(owner,contact);Set<Long> allowed=new HashSet<>();list(owner).forEach(c->allowed.add(c.id()));
    if(!allowed.containsAll(circleIds))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Circle not found");
    jdbc.update("DELETE FROM address_book_circle_contacts WHERE contact_id=?",contact);
    for(long id:new LinkedHashSet<>(circleIds))jdbc.update("INSERT INTO address_book_circle_contacts(contact_id,circle_id) VALUES (?,?)",contact,id);
    jdbc.update("UPDATE address_book_contacts SET circles_reviewed=TRUE WHERE id=?",contact);
  }
  public void markReviewed(long owner,long contact){
    requireContact(owner,contact);
    jdbc.update("UPDATE address_book_contacts SET circles_reviewed=TRUE WHERE user_id=? AND id=?",owner,contact);
  }
  private void lock(long owner){jdbc.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,owner);}
  private void requireContact(long owner,long id){if(jdbc.queryForObject("SELECT COUNT(*) FROM address_book_contacts WHERE user_id=? AND id=?",Long.class,owner,id)==0)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Contact not found");}
  private String key(String value){return value.trim().replaceAll("\\s+"," ").toLowerCase(Locale.ROOT);}
}

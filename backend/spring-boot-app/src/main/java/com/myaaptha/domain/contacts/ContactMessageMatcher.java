package com.myaaptha.domain.contacts;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;
import com.myaaptha.domain.privacy.UserBlockRepository;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
@Service public class ContactMessageMatcher {
 public record Target(Long userId,String name,Long contactId){}
 private final AddressBookService book;private final UserRepository users;private final UserBlockRepository blocks;private final JdbcTemplate db;
 public ContactMessageMatcher(AddressBookService book,UserRepository users,UserBlockRepository blocks,JdbcTemplate db){this.book=book;this.users=users;this.blocks=blocks;this.db=db;}
 public Target match(long owner,Long contactId){
  var empty=new Target(null,null,null);if(contactId==null)return empty;var contact=book.findOwned(owner,contactId).orElse(null);if(contact==null)return empty;
  Map<Long,UserEntity> matches=new LinkedHashMap<>();
  for(String phone:contact.phones()){String digits=phone.replaceAll("[^0-9]","");if(digits.startsWith("00"))digits=digits.substring(2);if(digits.length()>=7&&digits.length()<=15){users.findByPhoneNumber("+"+digits).ifPresent(u->matches.put(u.getId(),u));users.findByPhoneNumber(digits).ifPresent(u->matches.put(u.getId(),u));}}
  for(String email:contact.emails())users.findByEmail(email.trim().toLowerCase(Locale.ROOT)).ifPresent(u->matches.put(u.getId(),u));
  if(matches.size()!=1)return empty;var target=matches.values().iterator().next();long id=target.getId();
  if(id==owner||!"ACTIVE".equals(target.getAccountStatus())||"MANAGED".equals(target.getIdentityType())||blocks.blockedEitherWay(owner,id))return empty;
  boolean visible=db.queryForObject("SELECT COUNT(*) FROM app_settings WHERE user_id=? AND discoverable=TRUE",Integer.class,id)>0||db.queryForObject("SELECT COUNT(*) FROM relationships WHERE owner_user_id=? AND related_user_id=?",Integer.class,owner,id)>0;
  if(!visible)return empty;String name=(Objects.requireNonNullElse(target.getFirstName(),"")+" "+Objects.requireNonNullElse(target.getSurname(),"")).trim();return new Target(id,name.isEmpty()?target.getUsername():name,contactId);
 }
}

package com.myaaptha.domain.contacts;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.domain.contacts.AddressBookController.*;
import com.myaaptha.domain.network.NetworkService;
import com.myaaptha.domain.network.dto.AddPersonRequest;
import com.myaaptha.platform.security.FieldEncryption;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.*;
import java.text.Normalizer;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AddressBookService {
  public static final int MAX_CONTACTS=50000;
  private final JdbcTemplate jdbc;
  private final ObjectMapper json;
  private final FieldEncryption encryption;
  private final NetworkService network;
  public AddressBookService(JdbcTemplate jdbc,ObjectMapper json,FieldEncryption encryption,NetworkService network) {
    this.jdbc=jdbc;this.json=json;this.encryption=encryption;this.network=network;
  }
  public record Entry(long id,String displayName,List<String> phones,List<String> emails,String organization,List<String> groups,String source,Long relationshipId,List<Long> circleIds) {}
  public record Page(List<Entry> items,Long nextCursor,long total) {}
  public record ImportResult(int added,int updated,int unchanged,long total,List<Long> contactIds) {}

  @Transactional
  public ImportResult save(long owner,List<ContactInput> contacts,String source) {
    // Serialize imports and deletions for one owner, including retries from another device.
    lock(owner);
    if(contacts==null||contacts.isEmpty()||contacts.size()>100) bad("Import between 1 and 100 contacts per batch");
    if(!Set.of("device","csv","vcard","google","microsoft").contains(source)) bad("Unsupported contact source");
    Map<String,ContactInput> incoming=new LinkedHashMap<>();
    for(ContactInput raw:contacts) { ContactInput clean=normalize(raw);incoming.put(fingerprint(owner,clean),clean); }
    var existing=new NamedParameterJdbcTemplate(jdbc).query("SELECT * FROM address_book_contacts WHERE user_id=:owner AND fingerprint IN (:keys)",
        Map.of("owner",owner,"keys",incoming.keySet()),(rs,n)->Map.entry(rs.getString("fingerprint"),entry(rs)));
    Map<String,Entry> byKey=new HashMap<>();existing.forEach(value->byKey.put(value.getKey(),value.getValue()));
    long total=count(owner);int added=0,updated=0,unchanged=contacts.size()-incoming.size();
    if(total+incoming.keySet().stream().filter(key->!byKey.containsKey(key)).count()>MAX_CONTACTS)
      bad("The private address book supports up to 50,000 contacts. This batch was not saved.");
    for(var item:incoming.entrySet()) {
      ContactInput contact=item.getValue();Entry old=byKey.get(item.getKey());
      String data=encode(contact);
      if(old==null) {
        jdbc.update("INSERT INTO address_book_contacts(user_id,fingerprint,display_name,contact_data,source) VALUES (?,?,?,?,?)",
            owner,item.getKey(),contact.displayName(),encryption.encrypt(data),source);added++;
      } else if(old.displayName().equals(contact.displayName())&&old.phones().equals(contact.phones())&&old.emails().equals(contact.emails())&&old.organization().equals(contact.organization())&&old.groups().equals(contact.groups())) unchanged++;
      else {
        jdbc.update("UPDATE address_book_contacts SET display_name=?,contact_data=?,source=?,updated_at=CURRENT_TIMESTAMP WHERE user_id=? AND id=?",
            contact.displayName(),encryption.encrypt(data),source,owner,old.id());updated++;
      }
    }
    var ids=new NamedParameterJdbcTemplate(jdbc).queryForList("SELECT id FROM address_book_contacts WHERE user_id=:owner AND fingerprint IN (:keys)",Map.of("owner",owner,"keys",incoming.keySet()),Long.class);
    return new ImportResult(added,updated,unchanged,total+added,ids);
  }
  @Transactional(readOnly=true)
  public Page list(long owner,long after,int limit,String query,Long circleId) {
    if(after<0||limit<1||limit>100||query.length()>200) bad("Invalid address book page or search");
    String pattern="%"+query.trim().toLowerCase(Locale.ROOT).replace("!","!!").replace("%","!%").replace("_","!_")+"%";
    var items=circleId==null?jdbc.query("SELECT * FROM address_book_contacts WHERE user_id=? AND id>? AND LOWER(display_name) LIKE ? ESCAPE '!' ORDER BY id LIMIT ?",this::row,owner,after,pattern,limit+1):jdbc.query("SELECT c.* FROM address_book_contacts c JOIN address_book_circle_contacts cc ON cc.contact_id=c.id WHERE c.user_id=? AND c.id>? AND LOWER(c.display_name) LIKE ? ESCAPE '!' AND cc.circle_id=? ORDER BY c.id LIMIT ?",this::row,owner,after,pattern,circleId,limit+1);
    boolean more=items.size()>limit;if(more) items=new ArrayList<>(items.subList(0,limit));
    Map<Long,List<Long>> circleIds=new HashMap<>();
    if(!items.isEmpty())new NamedParameterJdbcTemplate(jdbc).query("SELECT contact_id,circle_id FROM address_book_circle_contacts WHERE contact_id IN (:ids)",Map.of("ids",items.stream().map(Entry::id).toList()),rs->{circleIds.computeIfAbsent(rs.getLong(1),key->new ArrayList<>()).add(rs.getLong(2));});
    items=items.stream().map(c->new Entry(c.id(),c.displayName(),c.phones(),c.emails(),c.organization(),c.groups(),c.source(),c.relationshipId(),circleIds.getOrDefault(c.id(),List.of()))).toList();
    return new Page(items,more?items.getLast().id():null,count(owner));
  }
  @Transactional
  public void delete(long owner,long id) {lock(owner);if(jdbc.update("DELETE FROM address_book_contacts WHERE user_id=? AND id=?",owner,id)==0) missing();}
  @Transactional
  public void clear(long owner,boolean confirm) {if(!confirm) bad("Confirm clearing your private address book");lock(owner);jdbc.update("DELETE FROM address_book_contacts WHERE user_id=?",owner);}
  @Transactional
  public Entry relate(long owner,long id,RelationRequest request) {
    lock(owner);Entry contact=required(owner,id);if(contact.relationshipId()!=null) return contact;
    String phone=request.phone()==null||request.phone().isBlank()?null:request.phone().trim();
    if(phone!=null&&!contact.phones().contains(phone)) bad("Choose a phone number saved on this contact");
    String email=contact.emails().isEmpty()?null:contact.emails().getFirst();
    if(phone==null&&email==null) bad("This contact needs a phone number or email before becoming a relation");
    var relation=network.addPerson(owner,new AddPersonRequest(contact.displayName(),phone,email,request.relationship(),"FRIENDS",null,
        phone==null?"MANAGED":"ACCOUNT",phone==null?"OTHER":null,null,null,null,"Added individually from my private address book",null));
    jdbc.update("UPDATE address_book_contacts SET relationship_id=? WHERE user_id=? AND id=?",relation.id(),owner,id);
    return required(owner,id);
  }
  public List<Entry> entries(long owner,List<Long> ids){if(ids.isEmpty())return List.of();return new NamedParameterJdbcTemplate(jdbc).query("SELECT * FROM address_book_contacts WHERE user_id=:owner AND id IN (:ids)",Map.of("owner",owner,"ids",ids),this::row);}
  private Entry required(long owner,long id) {var items=jdbc.query("SELECT * FROM address_book_contacts WHERE user_id=? AND id=?",this::row,owner,id);if(items.isEmpty())missing();return items.getFirst();}
  private Entry row(ResultSet rs,int number)throws SQLException{return entry(rs);}
  private Entry entry(ResultSet rs)throws SQLException {
    try {ContactInput data=json.readValue(encryption.decrypt(rs.getString("contact_data")),ContactInput.class);
      return new Entry(rs.getLong("id"),rs.getString("display_name"),data.phones(),data.emails(),data.organization(),data.groups()==null?List.of():data.groups(),rs.getString("source"),(Long)rs.getObject("relationship_id"),List.of());
    }catch(JsonProcessingException e){throw new IllegalStateException("Stored contact data could not be read");}
  }
  private long count(long owner){return jdbc.queryForObject("SELECT COUNT(*) FROM address_book_contacts WHERE user_id=?",Long.class,owner);}
  private void lock(long owner){jdbc.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,owner);}
  private ContactInput normalize(ContactInput raw) {
    if(raw==null) {bad("Contact is missing");}
    List<String> phones=values(raw.phones(),80),emails=values(raw.emails(),254);
    String name=clean(raw.displayName(),200),organization=clean(raw.organization(),300);
    if(name.isEmpty()) name=!phones.isEmpty()?phones.getFirst():!emails.isEmpty()?emails.getFirst():"Unnamed contact";
    if(name.length()>200)name=name.substring(0,200);
    return new ContactInput(name,phones,emails,organization,values(raw.groups(),100));
  }
  private List<String> values(List<String> values,int length) {
    if(values==null)return List.of();if(values.size()>20)bad("A contact may have at most 20 phone numbers or email addresses");
    return values.stream().map(v->clean(v,length)).filter(v->!v.isEmpty()).distinct().toList();
  }
  private String clean(String value,int length) {if(value==null)return "";String clean=value.trim();if(clean.length()>length)bad("A contact field exceeds the supported length");if(clean.chars().anyMatch(c->Character.isISOControl(c)))bad("A contact field contains unsupported control characters");return clean;}
  private String fingerprint(long owner,ContactInput contact) {
    var identity=List.of(Long.toString(owner),Normalizer.normalize(contact.displayName(),Normalizer.Form.NFKC).toLowerCase(Locale.ROOT),
        contact.phones().stream().map(p->p.replaceAll("[ ()\\-.]","")).sorted().toList(),contact.emails().stream().map(e->e.toLowerCase(Locale.ROOT)).sorted().toList());
    try {return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(json.writeValueAsBytes(identity)));}
    catch(Exception e){throw new IllegalStateException("Contact identity could not be generated");}
  }
  private String encode(ContactInput contact){try{return json.writeValueAsString(contact);}catch(JsonProcessingException e){throw new IllegalStateException("Contact could not be saved");}}
  private static void bad(String message){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,message);}
  private static void missing(){throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Contact not found");}
}

package com.myaaptha.domain.relationship;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.platform.security.FieldEncryption;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.security.Principal;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Project decisions and public configuration references; never accepts credential contents. */
@RestController @RequestMapping("/api/admin/project-inputs")
public class ProjectInputs {
 public record Field(String key,String label,String kind,List<String> options,boolean required){}
 public record Definition(String key,String title,String pendingWork,List<Field> fields){}
 public record Task(Definition definition,Map<String,String> values,boolean ready,long version,String updatedAt){}
 public record Save(@NotNull Map<String,String> values,boolean ready,long version){}
 private final JdbcTemplate db;private final ObjectMapper json;private final FieldEncryption encryption;
 public ProjectInputs(JdbcTemplate db,ObjectMapper json,FieldEncryption encryption){this.db=db;this.json=json;this.encryption=encryption;}
 private static Field choice(String key,String label,String... values){return new Field(key,label,"choice",List.of(values),true);}
 private static Field text(String key,String label,String kind){return new Field(key,label,kind,List.of(),false);}
 private static final List<Definition> DEFINITIONS=List.of(
  new Definition("meta","Instagram / Meta","Connect eligible professional accounts, permissions, review and webhook verification. Personal-account feed imports remain subject to Meta API availability.",List.of(choice("status","Meta setup status","Not started","App created","Permissions requested","Approved"),text("appId","Meta app ID","numeric"),choice("accountType","Instagram account type","Unknown","Personal","Creator","Business"),text("credentials","Meta credentials secret reference","secret-reference"))),
  new Definition("firebase","Android notifications and calls","Background incoming-call notifications, device token lifecycle and physical Android acceptance.",List.of(choice("status","Firebase setup status","Not started","Project created","Android app registered","Configured"),text("projectId","Firebase project ID","identifier"),text("appId","Firebase Android app ID","identifier"),text("credentials","Firebase service account secret reference","secret-reference"))),
  new Definition("apns","iOS notifications and calls","APNs / PushKit, CallKit integration, signing and physical iPhone acceptance.",List.of(choice("status","Apple setup status","Not started","Developer account ready","App registered","Configured"),text("teamId","Apple team ID","identifier"),text("bundleId","iOS bundle ID","identifier"),choice("environment","APNs environment","Undecided","Sandbox","Production","Both"),text("credentials","APNs signing key secret reference","secret-reference"))),
  new Definition("encryption","Encrypted messaging","Protocol, device identity, key verification, recovery, encrypted media and migration still require implementation and review. Saving a choice does not enable encryption.",List.of(choice("mode","Chat encryption model","Undecided","Encrypted chats by default","Separate encrypted chats alongside searchable chats"),choice("recovery","Recovery preference","Undecided","Device transfer only","User-held recovery key","Encrypted backup with user passphrase"))),
  new Definition("devices","Physical device acceptance","Test real background calls, camera, microphone, notifications, network changes and voice notes on Android and iPhone.",List.of(choice("android","Android test device","Not available","Available","Testing complete"),choice("ios","iPhone test device","Not available","Available","Testing complete"))),
  new Definition("community-parity","Remaining community features","Full parity is incomplete: communities/channels, event reminders and public invites, voice status, music/editor tools, view-once media, video notes, stickers/GIFs, contact cards, live location, collaborative collections, discovery ranking, native screen sharing, large calls and live streaming, companion devices, encrypted backups and biometric chat locks. Commercial tools are deferred.",List.of(choice("priority","Next implementation priority","Undecided","Communities and channels","Stories and media editing","Large voice/video calls","Discovery and privacy controls")))
 );
 @GetMapping public List<Task> list(){return DEFINITIONS.stream().map(this::read).toList();}
 @PostMapping("/{key}") @Transactional public Task save(Principal principal,@PathVariable String key,@Valid @RequestBody Save input){
  Definition definition=DEFINITIONS.stream().filter(d->d.key().equals(key)).findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Task not found"));
  if(input.values().size()>definition.fields().size())throw bad("Unknown input field");Map<String,String> clean=new TreeMap<>();
  for(var entry:input.values().entrySet()){
   Field field=definition.fields().stream().filter(f->f.key().equals(entry.getKey())).findFirst().orElseThrow(()->bad("Unknown input field"));String value=entry.getValue();if(value==null)throw bad("Input cannot be null");value=value.trim();if(value.length()>300)throw bad("Input is too long");if(value.isEmpty())continue;
   boolean valid=switch(field.kind()) {case "choice"->field.options().contains(value);case "numeric"->value.matches("[0-9]{5,40}");case "identifier"->value.matches("[A-Za-z0-9][A-Za-z0-9._:-]{1,199}");case "secret-reference"->value.matches("projects/[A-Za-z0-9._:-]+/secrets/[A-Za-z0-9_-]+/versions/(latest|[0-9]+)");default->false;};
   if(!valid)throw bad("Invalid "+field.label()+". Store credentials in Secret Manager and enter only the reference");clean.put(field.key(),value);
  }
  if(input.ready())for(Field field:definition.fields())if(field.required()&&(!clean.containsKey(field.key())||Set.of("Undecided","Unknown","Not started","Not available").contains(clean.get(field.key()))))throw bad("Complete "+field.label()+" before requesting review");
  db.queryForObject("SELECT id FROM project_input_lock WHERE id=1 FOR UPDATE",Integer.class);Task current=read(definition);if(current.version()!=input.version())throw new ResponseStatusException(HttpStatus.CONFLICT,"Inputs changed. Refresh before saving");String encoded;try{encoded=encryption.encrypt(json.writeValueAsString(clean));}catch(Exception e){throw new IllegalStateException("Inputs could not be saved");}
  if(current.version()==0)db.update("INSERT INTO project_input_tasks(task_key,input_data,ready,version,updated_by) VALUES(?,?,?,1,?)",key,encoded,input.ready(),Long.parseLong(principal.getName()));else db.update("UPDATE project_input_tasks SET input_data=?,ready=?,version=version+1,updated_at=CURRENT_TIMESTAMP,updated_by=? WHERE task_key=?",encoded,input.ready(),Long.parseLong(principal.getName()),key);
  return read(definition);
 }
 private Task read(Definition d){var rows=db.query("SELECT input_data,ready,version,updated_at FROM project_input_tasks WHERE task_key=?",(rs,n)->{try{Map<String,String> values=json.readValue(encryption.decrypt(rs.getString(1)),new TypeReference<>(){});return new Task(d,values,rs.getBoolean(2),rs.getLong(3),rs.getString(4));}catch(Exception e){throw new IllegalStateException("Inputs could not be read");}},d.key());return rows.isEmpty()?new Task(d,Map.of(),false,0,null):rows.getFirst();}
 private static ResponseStatusException bad(String message){return new ResponseStatusException(HttpStatus.BAD_REQUEST,message);}
}

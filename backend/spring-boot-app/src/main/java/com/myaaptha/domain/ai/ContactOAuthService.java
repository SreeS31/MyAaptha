package com.myaaptha.domain.ai;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.*;
import com.myaaptha.domain.ai.ContactOAuthStateStore.Pending;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class ContactOAuthService {
  private final RestClient http;
  private final com.myaaptha.domain.contacts.AddressBookImportService addressBook;
  private final RestClient ai;
  private final AiPreferenceService preferences;
  private final SecureRandom random=new SecureRandom();
  private final ContactOAuthStateStore stateStore;
  private final String publicApiBaseUrl,webOrigin,googleId,googleSecret,microsoftId,microsoftSecret;

  public ContactOAuthService(@Value("${myaaptha.ai.base-url:http://localhost:8081/api/v1}") String aiBaseUrl,
      @Value("${myaaptha.contact-oauth.public-api-base-url:http://localhost:8080}") String publicApiBaseUrl,
      @Value("${myaaptha.contact-oauth.web-origin:http://localhost:3000}") String webOrigin,
      @Value("${myaaptha.contact-oauth.google-client-id:}") String googleId,
      @Value("${myaaptha.contact-oauth.google-client-secret:}") String googleSecret,
      @Value("${myaaptha.contact-oauth.microsoft-client-id:}") String microsoftId,
      @Value("${myaaptha.contact-oauth.microsoft-client-secret:}") String microsoftSecret, com.myaaptha.domain.contacts.AddressBookImportService addressBook, AiPreferenceService preferences, ContactOAuthStateStore stateStore) {
    this.addressBook=addressBook;this.preferences=preferences;this.stateStore=stateStore;
    var factory=new org.springframework.http.client.SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(5000);factory.setReadTimeout(25000);
    this.http=RestClient.builder().requestFactory(factory).build();
    this.ai=RestClient.builder().baseUrl(aiBaseUrl).build();this.publicApiBaseUrl=trimSlash(publicApiBaseUrl);
    this.webOrigin=trimSlash(webOrigin);this.googleId=googleId;this.googleSecret=googleSecret;
    this.microsoftId=microsoftId;this.microsoftSecret=microsoftSecret;
  }

  public Map<String,Boolean> availability(){return Map.of("google",!googleId.isBlank()&&!googleSecret.isBlank(),"microsoft",!microsoftId.isBlank()&&!microsoftSecret.isBlank());}
  public StartResult start(Long userId,StartRequest request){return start(userId,request,false,false);}
  public StartResult startAddressBook(Long userId,StartRequest request,boolean organize){return start(userId,request,true,organize);}
  private StartResult start(Long userId,StartRequest request,boolean privateBook,boolean organize){
    String provider=normalizeProvider(request.provider());String email=clean(request.email());
    if(email==null||!email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Enter a valid email address");
    configured(provider);String state=token(32),verifier=token(48),resultKey=token(32),challenge=base64(sha256(verifier));
    stateStore.putPending(state,new Pending(userId,provider,verifier,resultKey,privateBook));
    String callback=callback(provider);String url;
    if(provider.equals("google"))url=UriComponentsBuilder.fromUriString("https://accounts.google.com/o/oauth2/v2/auth")
        .queryParam("client_id",googleId).queryParam("redirect_uri",callback).queryParam("response_type","code")
        .queryParam("scope","https://www.googleapis.com/auth/contacts.readonly")
        .queryParam("access_type","online").queryParam("prompt","select_account consent").queryParam("login_hint",email)
        .queryParam("state",state).queryParam("code_challenge",challenge).queryParam("code_challenge_method","S256").build().encode().toUriString();
    else url=UriComponentsBuilder.fromUriString("https://login.microsoftonline.com/common/oauth2/v2.0/authorize")
        .queryParam("client_id",microsoftId).queryParam("redirect_uri",callback).queryParam("response_type","code")
        .queryParam("response_mode","query").queryParam("scope","openid profile https://graph.microsoft.com/Contacts.Read")
        .queryParam("prompt","select_account").queryParam("login_hint",email).queryParam("state",state)
        .queryParam("code_challenge",challenge).queryParam("code_challenge_method","S256").build().encode().toUriString();
    return new StartResult(url,provider,resultKey);
  }

  public String callback(String pathProvider,String code,String state,String oauthError){
    String provider=normalizeProvider(pathProvider);Pending session=stateStore.takePending(state,provider);
    if(session==null)return popup(null,"The contact authorization expired. Please try again.");
    if(oauthError!=null||code==null||code.isBlank()){stateStore.putResult(session.resultKey(),session.userId(),Map.of("status","failed","message","Contact access was cancelled or denied. Nothing was imported."));return popup(null,"Contact access was cancelled or denied.");}
    try{
      if(!session.privateBook())preferences.requireSensitiveDataAllowed(session.userId());
      String accessToken=exchange(provider,code,session.verifier());
      List<Map<String,Object>> contacts=provider.equals("google")?googleContacts(accessToken,session.privateBook()?50000:2000):microsoftContacts(accessToken,session.privateBook()?50000:2000);
      if(session.privateBook()) {
        var preview=contacts.stream().map(c->new com.myaaptha.domain.contacts.AddressBookController.ContactInput(
            String.valueOf(c.get("display_name")),strings(c.get("phones")),strings(c.get("emails")),String.valueOf(c.get("organization")),strings(c.get("labels")))).toList();
        stateStore.putResult(session.resultKey(),session.userId(),Map.of("status","review","message","Review and select contacts in MyAaptha. Nothing has been saved.","contacts",preview));
        return "<!doctype html><html><body><p>Contacts ready for review. Return to MyAaptha to select contacts and save.</p></body></html>";
      }
      if(contacts.isEmpty()){stateStore.putResult(session.resultKey(),session.userId(),List.of());return popup(session.resultKey(),null);}
      preferences.requireSensitiveDataAllowed(session.userId());
      Object suggestions=ai.post().uri("/contacts/organize").body(Map.of("consent",true,"contacts",contacts)).retrieve().body(Object.class);
      stateStore.putResult(session.resultKey(),session.userId(),suggestions);
      return popup(session.resultKey(),null);
    }catch(ResponseStatusException exception){
      if(exception.getStatusCode().value()==503)throw exception;
      String message=switch(exception.getStatusCode().value()) {
        case 403 -> "Contact analysis permission is disabled. Nothing was imported.";
        case 413 -> "The contact preview is too large. Try a smaller import. Nothing was saved.";
        default -> "Contacts could not be imported. Please try again.";
      };
      stateStore.putResult(session.resultKey(),session.userId(),Map.of("status","failed","message",message));return popup(null,message);
    }catch(Exception exception){stateStore.putResult(session.resultKey(),session.userId(),Map.of("status","failed","message","Contacts could not be imported. Check provider access and the 50,000-contact limit, then retry."));return popup(null,"Contacts could not be imported. Check provider configuration and try again.");}
  }

  public Object consume(Long userId,String key){return stateStore.takeResult(key,userId);}

  public Object consumeOrganizer(Long userId,String key){
    Object value=consume(userId,key);
    if(value instanceof Map<?,?> result && "failed".equals(result.get("status")))
      throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,String.valueOf(result.get("message")));
    return value;
  }

  private String exchange(String provider,String code,String verifier){
    var form=new LinkedMultiValueMap<String,String>();form.add("client_id",provider.equals("google")?googleId:microsoftId);form.add("client_secret",provider.equals("google")?googleSecret:microsoftSecret);form.add("code",code);form.add("redirect_uri",callback(provider));form.add("grant_type","authorization_code");form.add("code_verifier",verifier);
    String endpoint=provider.equals("google")?"https://oauth2.googleapis.com/token":"https://login.microsoftonline.com/common/oauth2/v2.0/token";
    Map<?,?> body=http.post().uri(endpoint).contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form).retrieve().body(Map.class);
    Object token=body==null?null:body.get("access_token");if(token==null)throw new IllegalStateException("Missing access token");return token.toString();
  }

  private List<Map<String,Object>> googleContacts(String token,int maximum){Map<String,String> groups=googleGroups(token);List<Map<String,Object>> contacts=new ArrayList<>();int pages=0;String page=null;do{if(++pages>100)throw new IllegalStateException("Too many contact pages");var builder=UriComponentsBuilder.fromUriString("https://people.googleapis.com/v1/people/me/connections").queryParam("personFields","names,emailAddresses,phoneNumbers,organizations,memberships").queryParam("pageSize",1000);if(page!=null)builder.queryParam("pageToken",page);Map<?,?> body=get(builder.build().encode().toUriString(),token);for(Object raw:list(body,"connections")){if(!(raw instanceof Map<?,?> person))continue;String name=firstNested(person,"names","displayName");if(name==null)name=Optional.ofNullable(firstNested(person,"phoneNumbers","value")).orElse(Optional.ofNullable(firstNested(person,"emailAddresses","value")).orElse("Unnamed contact"));contacts.add(contact("google-"+contacts.size(),name,nested(person,"phoneNumbers","value"),nested(person,"emailAddresses","value"),firstNested(person,"organizations","name"),firstNested(person,"organizations","title"),nested(person,"memberships","contactGroupMembership.contactGroupResourceName").stream().map(groups::get).filter(Objects::nonNull).toList()));if(contacts.size()>maximum)throw new IllegalStateException("Contact limit exceeded");}page=string(body.get("nextPageToken"));}while(page!=null);return contacts;}
  private record GraphPage(String url,String group,boolean folders){}
  private List<Map<String,Object>> microsoftContacts(String token,int maximum){
    Map<String,Map<String,Object>> contacts=new LinkedHashMap<>();Deque<GraphPage> pages=new ArrayDeque<>();Set<String> visited=new HashSet<>(),folders=new HashSet<>();int requests=0;
    String fields="id,displayName,emailAddresses,mobilePhone,businessPhones,homePhones,companyName,jobTitle,categories";
    pages.add(new GraphPage("https://graph.microsoft.com/v1.0/me/contacts?$select="+fields+"&$top=999","",false));
    pages.add(new GraphPage("https://graph.microsoft.com/v1.0/me/contactFolders?$select=id,displayName&$top=100","",true));
    while(!pages.isEmpty()){
      GraphPage page=pages.removeFirst();if(++requests>2000||!visited.add(page.url()))throw new IllegalStateException("Contact paging limit exceeded");
      Map<?,?> body=get(page.url(),token);
      for(Object raw:list(body,"value")){
        if(!(raw instanceof Map<?,?> person))continue;
        if(page.folders()){
          String id=string(person.get("id"));if(id==null||!folders.add(id))continue;if(folders.size()>500)throw new IllegalStateException("Contact folder limit exceeded");
          String name=Optional.ofNullable(string(person.get("displayName"))).orElse("");
          String base=UriComponentsBuilder.fromUriString("https://graph.microsoft.com/v1.0").pathSegment("me","contactFolders",id).build().encode().toUriString();
          pages.add(new GraphPage(base+"/contacts?$select="+fields+"&$top=999",name.equalsIgnoreCase("Contacts")?"":name,false));
          pages.add(new GraphPage(base+"/childFolders?$select=id,displayName&$top=100","",true));continue;
        }
        String name=Optional.ofNullable(string(person.get("displayName"))).orElse("Unnamed contact");
        List<String> phones=new ArrayList<>();String mobile=string(person.get("mobilePhone"));if(mobile!=null)phones.add(mobile);phones.addAll(strings(person.get("businessPhones")));phones.addAll(strings(person.get("homePhones")));
        List<String> emails=new ArrayList<>();for(Object entry:list(person,"emailAddresses"))if(entry instanceof Map<?,?> map){String address=string(map.get("address"));if(address!=null)emails.add(address);}
        List<String> labels=new ArrayList<>(strings(person.get("categories")));if(!page.group().isBlank())labels.add(page.group());
        String id=Optional.ofNullable(string(person.get("id"))).orElse("generated-"+contacts.size());
        if(contacts.containsKey(id)){labels.addAll(strings(contacts.get(id).get("labels")));contacts.get(id).put("labels",labels.stream().distinct().toList());}
        else contacts.put(id,contact("microsoft-"+contacts.size(),name,phones,emails,string(person.get("companyName")),string(person.get("jobTitle")),labels));
        if(contacts.size()>maximum)throw new IllegalStateException("Contact limit exceeded");
      }
      String next=string(body.get("@odata.nextLink"));if(next!=null)pages.add(new GraphPage(next,page.group(),page.folders()));
    }
    return new ArrayList<>(contacts.values());
  }
  private Map<String,String> googleGroups(String token){
    Map<String,String> groups=new HashMap<>();String page=null;int pages=0;
    do{if(++pages>100)throw new IllegalStateException("Too many group pages");
      var uri=UriComponentsBuilder.fromUriString("https://people.googleapis.com/v1/contactGroups").queryParam("pageSize",1000);if(page!=null)uri.queryParam("pageToken",page);
      var body=get(uri.build().encode().toUriString(),token);
      for(Object raw:list(body,"contactGroups"))if(raw instanceof Map<?,?> group&&"USER_CONTACT_GROUP".equals(group.get("groupType"))){String id=string(group.get("resourceName")),name=string(group.get("name"));if(id!=null&&name!=null)groups.put(id,name);}
      page=string(body.get("nextPageToken"));
    }while(page!=null);return groups;
  }
  private Map<?,?> get(String url,String token){URI uri=URI.create(url);if(!"https".equals(uri.getScheme())||uri.getRawUserInfo()!=null||!Set.of("people.googleapis.com","graph.microsoft.com").contains(uri.getHost()))throw new IllegalStateException("Unsupported contact provider page");Map<?,?> body=http.get().uri(URI.create(url)).header(HttpHeaders.AUTHORIZATION,"Bearer "+token).retrieve().body(Map.class);return body==null?Map.of():body;}
  private Map<String,Object> contact(String key,String name,List<String> phones,List<String> emails,String org,String title,List<String> labels){Map<String,Object> item=new LinkedHashMap<>();item.put("contact_key",key);item.put("display_name",name);item.put("phones",phones);item.put("emails",emails);item.put("organization",org==null?"":org);item.put("job_title",title==null?"":title);item.put("labels",labels);return item;}
  private String popup(String key,String error){String payload=key!=null?"{type:'myaaptha-contact-import',resultKey:'"+key+"'}":"{type:'myaaptha-contact-import',error:'"+js(error)+"'}";return "<!doctype html><html><body><p>Returning to MyAaptha…</p><script>if(window.opener){window.opener.postMessage("+payload+",'"+js(webOrigin)+"');window.close();}else{location.href='"+js(webOrigin)+"/dashboard';}</script></body></html>";}
  private void configured(String provider){if(provider.equals("google")&&(googleId.isBlank()||googleSecret.isBlank()))throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Google Contacts is not configured yet");if(provider.equals("microsoft")&&(microsoftId.isBlank()||microsoftSecret.isBlank()))throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Outlook Contacts is not configured yet");}
  private String callback(String provider){return publicApiBaseUrl+"/api/contact-organizer/oauth/callback/"+provider;}
  private String normalizeProvider(String value){String provider=clean(value);if(provider==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose Google or Outlook");provider=provider.toLowerCase(Locale.ROOT);if(provider.equals("outlook"))provider="microsoft";if(!Set.of("google","microsoft").contains(provider))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose Google or Outlook");return provider;}
  private String token(int bytes){byte[] value=new byte[bytes];random.nextBytes(value);return base64(value);}
  private String base64(byte[] value){return Base64.getUrlEncoder().withoutPadding().encodeToString(value);}private byte[] sha256(String value){try{return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.US_ASCII));}catch(Exception exception){throw new IllegalStateException(exception);}}
  private String clean(String value){return value==null||value.isBlank()?null:value.trim();}private String string(Object value){return value==null||value.toString().isBlank()?null:value.toString();}private String trimSlash(String value){return value.replaceAll("/+$","");}private String js(String value){return value==null?"":value.replace("\\","\\\\").replace("'","\\'").replace("\r","").replace("\n"," ").replace("<","\\x3c");}
  private List<?> list(Map<?,?> map,String key){Object value=map.get(key);return value instanceof List<?> items?items:List.of();}private List<String> strings(Object value){if(!(value instanceof List<?> items))return new ArrayList<>();return items.stream().map(this::string).filter(Objects::nonNull).toList();}
  private List<String> nested(Map<?,?> map,String listKey,String valuePath){List<String> values=new ArrayList<>();for(Object raw:list(map,listKey))if(raw instanceof Map<?,?> item){Object current=item;for(String key:valuePath.split("\\.")){if(!(current instanceof Map<?,?> currentMap)){current=null;break;}current=currentMap.get(key);}String text=string(current);if(text!=null)values.add(text);}return values;}private String firstNested(Map<?,?> map,String listKey,String key){List<String> values=nested(map,listKey,key);return values.isEmpty()?null:values.get(0);}
  public record StartRequest(String email,String provider){}public record StartResult(String authorizationUrl,String provider,String resultKey){}
}

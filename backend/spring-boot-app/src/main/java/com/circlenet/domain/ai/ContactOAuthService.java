package com.circlenet.domain.ai;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class ContactOAuthService {
  private static final long LIFE_SECONDS=600;
  private final RestClient http=RestClient.create();
  private final RestClient ai;
  private final SecureRandom random=new SecureRandom();
  private final Map<String,Pending> pending=new ConcurrentHashMap<>();
  private final Map<String,Result> results=new ConcurrentHashMap<>();
  private final String publicApiBaseUrl,webOrigin,googleId,googleSecret,microsoftId,microsoftSecret;

  public ContactOAuthService(@Value("${circlenet.ai.base-url:http://localhost:8081/api/v1}") String aiBaseUrl,
      @Value("${circlenet.contact-oauth.public-api-base-url:http://localhost:8080}") String publicApiBaseUrl,
      @Value("${circlenet.contact-oauth.web-origin:http://localhost:3000}") String webOrigin,
      @Value("${circlenet.contact-oauth.google-client-id:}") String googleId,
      @Value("${circlenet.contact-oauth.google-client-secret:}") String googleSecret,
      @Value("${circlenet.contact-oauth.microsoft-client-id:}") String microsoftId,
      @Value("${circlenet.contact-oauth.microsoft-client-secret:}") String microsoftSecret) {
    this.ai=RestClient.builder().baseUrl(aiBaseUrl).build();this.publicApiBaseUrl=trimSlash(publicApiBaseUrl);
    this.webOrigin=trimSlash(webOrigin);this.googleId=googleId;this.googleSecret=googleSecret;
    this.microsoftId=microsoftId;this.microsoftSecret=microsoftSecret;
  }

  public StartResult start(Long userId,StartRequest request){
    cleanup();String provider=normalizeProvider(request.provider());String email=clean(request.email());
    if(email==null||!email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Enter a valid email address");
    configured(provider);String state=token(32),verifier=token(48),resultKey=token(32),challenge=base64(sha256(verifier));
    pending.put(state,new Pending(userId,provider,email,verifier,resultKey,Instant.now().plusSeconds(LIFE_SECONDS)));
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
    cleanup();Pending session=pending.remove(state);String provider=normalizeProvider(pathProvider);
    if(session==null||!session.provider().equals(provider)||session.expiresAt().isBefore(Instant.now()))return popup(null,"The contact authorization expired. Please try again.");
    if(oauthError!=null||code==null||code.isBlank())return popup(null,"Contact access was cancelled or denied.");
    try{
      String accessToken=exchange(provider,code,session.verifier());
      List<Map<String,Object>> contacts=provider.equals("google")?googleContacts(accessToken):microsoftContacts(accessToken);
      if(contacts.isEmpty())return popup(null,"No contacts were found in this account.");
      Object suggestions=ai.post().uri("/contacts/organize").body(Map.of("consent",true,"contacts",contacts)).retrieve().body(Object.class);
      results.put(session.resultKey(),new Result(session.userId(),suggestions,Instant.now().plusSeconds(LIFE_SECONDS)));
      return popup(session.resultKey(),null);
    }catch(Exception exception){return popup(null,"Contacts could not be imported. Check provider configuration and try again.");}
  }

  public Object consume(Long userId,String key){cleanup();Result result=results.remove(key);if(result==null||!result.userId().equals(userId)||result.expiresAt().isBefore(Instant.now()))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"This contact import result expired");return result.suggestions();}

  private String exchange(String provider,String code,String verifier){
    var form=new LinkedMultiValueMap<String,String>();form.add("client_id",provider.equals("google")?googleId:microsoftId);form.add("client_secret",provider.equals("google")?googleSecret:microsoftSecret);form.add("code",code);form.add("redirect_uri",callback(provider));form.add("grant_type","authorization_code");form.add("code_verifier",verifier);
    String endpoint=provider.equals("google")?"https://oauth2.googleapis.com/token":"https://login.microsoftonline.com/common/oauth2/v2.0/token";
    Map<?,?> body=http.post().uri(endpoint).contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form).retrieve().body(Map.class);
    Object token=body==null?null:body.get("access_token");if(token==null)throw new IllegalStateException("Missing access token");return token.toString();
  }

  private List<Map<String,Object>> googleContacts(String token){List<Map<String,Object>> contacts=new ArrayList<>();String page=null;do{var builder=UriComponentsBuilder.fromUriString("https://people.googleapis.com/v1/people/me/connections").queryParam("personFields","names,emailAddresses,phoneNumbers,organizations,memberships").queryParam("pageSize",1000);if(page!=null)builder.queryParam("pageToken",page);Map<?,?> body=get(builder.build().encode().toUriString(),token);for(Object raw:list(body,"connections")){if(!(raw instanceof Map<?,?> person))continue;String name=firstNested(person,"names","displayName");if(name==null)continue;contacts.add(contact("google-"+contacts.size(),name,nested(person,"phoneNumbers","value"),nested(person,"emailAddresses","value"),firstNested(person,"organizations","name"),firstNested(person,"organizations","title"),nested(person,"memberships","contactGroupMembership.contactGroupResourceName")));if(contacts.size()>=2000)break;}page=string(body.get("nextPageToken"));}while(page!=null&&contacts.size()<2000);return contacts;}
  private List<Map<String,Object>> microsoftContacts(String token){List<Map<String,Object>> contacts=new ArrayList<>();String url="https://graph.microsoft.com/v1.0/me/contacts?$select=id,displayName,emailAddresses,mobilePhone,businessPhones,companyName,jobTitle,categories&$top=999";while(url!=null&&contacts.size()<2000){Map<?,?> body=get(url,token);for(Object raw:list(body,"value")){if(!(raw instanceof Map<?,?> person))continue;String name=string(person.get("displayName"));if(name==null)continue;List<String> phones=new ArrayList<>();String mobile=string(person.get("mobilePhone"));if(mobile!=null)phones.add(mobile);phones.addAll(strings(person.get("businessPhones")));List<String> emails=new ArrayList<>();for(Object entry:list(person,"emailAddresses"))if(entry instanceof Map<?,?> map){String address=string(map.get("address"));if(address!=null)emails.add(address);}contacts.add(contact("microsoft-"+contacts.size(),name,phones,emails,string(person.get("companyName")),string(person.get("jobTitle")),strings(person.get("categories"))));if(contacts.size()>=2000)break;}url=string(body.get("@odata.nextLink"));}return contacts;}
  private Map<?,?> get(String url,String token){Map<?,?> body=http.get().uri(URI.create(url)).header(HttpHeaders.AUTHORIZATION,"Bearer "+token).retrieve().body(Map.class);return body==null?Map.of():body;}
  private Map<String,Object> contact(String key,String name,List<String> phones,List<String> emails,String org,String title,List<String> labels){Map<String,Object> item=new LinkedHashMap<>();item.put("contact_key",key);item.put("display_name",name);item.put("phones",phones);item.put("emails",emails);item.put("organization",org==null?"":org);item.put("job_title",title==null?"":title);item.put("labels",labels);return item;}
  private String popup(String key,String error){String payload=key!=null?"{type:'circlenet-contact-import',resultKey:'"+key+"'}":"{type:'circlenet-contact-import',error:'"+js(error)+"'}";return "<!doctype html><html><body><p>Returning to CircleNet…</p><script>if(window.opener){window.opener.postMessage("+payload+",'"+js(webOrigin)+"');window.close();}else{location.href='"+js(webOrigin)+"/dashboard';}</script></body></html>";}
  private void configured(String provider){if(provider.equals("google")&&(googleId.isBlank()||googleSecret.isBlank()))throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Google Contacts is not configured yet");if(provider.equals("microsoft")&&(microsoftId.isBlank()||microsoftSecret.isBlank()))throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Outlook Contacts is not configured yet");}
  private String callback(String provider){return publicApiBaseUrl+"/api/contact-organizer/oauth/callback/"+provider;}
  private String normalizeProvider(String value){String provider=clean(value);if(provider==null)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose Google or Outlook");provider=provider.toLowerCase(Locale.ROOT);if(provider.equals("outlook"))provider="microsoft";if(!Set.of("google","microsoft").contains(provider))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose Google or Outlook");return provider;}
  private void cleanup(){Instant now=Instant.now();pending.entrySet().removeIf(entry->entry.getValue().expiresAt().isBefore(now));results.entrySet().removeIf(entry->entry.getValue().expiresAt().isBefore(now));}
  private String token(int bytes){byte[] value=new byte[bytes];random.nextBytes(value);return base64(value);}
  private String base64(byte[] value){return Base64.getUrlEncoder().withoutPadding().encodeToString(value);}private byte[] sha256(String value){try{return MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.US_ASCII));}catch(Exception exception){throw new IllegalStateException(exception);}}
  private String clean(String value){return value==null||value.isBlank()?null:value.trim();}private String string(Object value){return value==null||value.toString().isBlank()?null:value.toString();}private String trimSlash(String value){return value.replaceAll("/+$","");}private String js(String value){return value==null?"":value.replace("\\","\\\\").replace("'","\\'").replace("\r","").replace("\n"," ").replace("<","\\x3c");}
  private List<?> list(Map<?,?> map,String key){Object value=map.get(key);return value instanceof List<?> items?items:List.of();}private List<String> strings(Object value){if(!(value instanceof List<?> items))return new ArrayList<>();return items.stream().map(this::string).filter(Objects::nonNull).toList();}
  private List<String> nested(Map<?,?> map,String listKey,String valuePath){List<String> values=new ArrayList<>();for(Object raw:list(map,listKey))if(raw instanceof Map<?,?> item){Object current=item;for(String key:valuePath.split("\\.")){if(!(current instanceof Map<?,?> currentMap)){current=null;break;}current=currentMap.get(key);}String text=string(current);if(text!=null)values.add(text);}return values;}private String firstNested(Map<?,?> map,String listKey,String key){List<String> values=nested(map,listKey,key);return values.isEmpty()?null:values.get(0);}
  public record StartRequest(String email,String provider){}public record StartResult(String authorizationUrl,String provider,String resultKey){}private record Pending(Long userId,String provider,String email,String verifier,String resultKey,Instant expiresAt){}private record Result(Long userId,Object suggestions,Instant expiresAt){}
}

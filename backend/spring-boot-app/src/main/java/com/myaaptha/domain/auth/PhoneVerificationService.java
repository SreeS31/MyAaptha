package com.myaaptha.domain.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.myaaptha.platform.state.EphemeralState;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.http.*;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PhoneVerificationService {
 private final boolean required;private final String account,secret,service,captchaSecret,hostname,verificationUrl;private final RestClient http;private final EphemeralState state;
 public PhoneVerificationService(RestClient.Builder builder,EphemeralState state,@Value("${security.phone.required:false}") boolean required,@Value("${TWILIO_ACCOUNT_SID:}") String account,@Value("${TWILIO_AUTH_TOKEN:}") String secret,@Value("${TWILIO_VERIFY_SERVICE_SID:}") String service,@Value("${TURNSTILE_SECRET_KEY:}") String captchaSecret,@Value("${myaaptha.contact-oauth.web-origin:http://localhost:3000}") String origin){
   this.required=required;this.state=state;this.account=account;this.secret=secret;this.service=service;this.captchaSecret=captchaSecret;this.hostname=URI.create(origin).getHost();this.verificationUrl=URI.create(origin).resolve("/verify-phone").toString();
   var factory=new JdkClientHttpRequestFactory(java.net.http.HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build());factory.setReadTimeout(Duration.ofSeconds(8));http=builder.requestFactory(factory).build();
 }
 public boolean required(){return required;}
 public boolean configured(){return required&&!account.isBlank()&&!secret.isBlank()&&!service.isBlank()&&!captchaSecret.isBlank()&&hostname!=null;}
 public String verificationUrl(){return configured()?verificationUrl:null;}
 public String normalize(String phone){String clean=phone==null?"":phone.replaceAll("[ ()-]","");if(clean.matches("[0-9]{10}"))clean="+91"+clean;if(!clean.matches("\\+[1-9][0-9]{7,14}"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Use a phone number with country code");return clean;}
 private String key(String phone){try{return HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(phone.getBytes(StandardCharsets.UTF_8)));}catch(Exception error){throw new IllegalStateException(error);}}
 public void start(String number,String captcha,String ip){
   if(!configured())throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Phone verification is not configured");String phone=normalize(number);
   if(captcha==null||captcha.isBlank()||captcha.length()>2048)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Complete the security challenge");
   if(state.increment("sms-ip:"+ip,Duration.ofHours(1))>10||state.increment("sms-phone:"+key(phone),Duration.ofHours(1))>3)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"Please wait before requesting another code");
   try{
     JsonNode result=http.post().uri("https://challenges.cloudflare.com/turnstile/v0/siteverify").body(Map.of("secret",captchaSecret,"response",captcha,"remoteip",ip)).retrieve().body(JsonNode.class);
     if(result==null||!result.path("success").asBoolean()||!hostname.equals(result.path("hostname").asText())||!"phone-verification".equals(result.path("action").asText()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Security challenge failed");
     provider("Verifications",Map.of("To",phone,"Channel","sms"));
   }catch(org.springframework.web.client.RestClientException error){throw unavailable();}
 }
 public boolean verify(String number,String code){
   if(!required)return false;if(!configured())throw unavailable();String phone=normalize(number);
   if(code==null||!code.matches("[0-9]{4,10}"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Enter the SMS verification code");
   if(state.increment("sms-check:"+key(phone),Duration.ofMinutes(10))>10)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"Too many verification attempts");
   try{JsonNode result=provider("VerificationCheck",Map.of("To",phone,"Code",code));if(result==null||!"approved".equals(result.path("status").asText()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Verification code is invalid or expired");return true;}
   catch(org.springframework.web.client.HttpClientErrorException error){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Verification code is invalid or expired");}
   catch(org.springframework.web.client.RestClientException error){throw unavailable();}
 }
 private JsonNode provider(String endpoint,Map<String,String> values){var form=new LinkedMultiValueMap<String,String>();values.forEach(form::add);return http.post().uri("https://verify.twilio.com/v2/Services/"+service+"/"+endpoint).headers(h->h.setBasicAuth(account,secret)).contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form).retrieve().body(JsonNode.class);}
 private ResponseStatusException unavailable(){return new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Phone verification is temporarily unavailable");}
}

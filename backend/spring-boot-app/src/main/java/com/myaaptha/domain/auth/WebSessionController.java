package com.myaaptha.domain.auth;

import com.myaaptha.domain.auth.dto.*;
import jakarta.servlet.http.*;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/web-auth")
public class WebSessionController {
  public static final String ACCESS="__Host-myaaptha_access",REFRESH="__Host-myaaptha_refresh";
  private final AuthService auth;private final boolean secure;private final long refreshDays;
  public WebSessionController(AuthService auth,@Value("${security.web-cookie.secure:true}") boolean secure,@Value("${security.jwt.refresh-token-days:7}") long refreshDays){this.auth=auth;this.secure=secure;this.refreshDays=refreshDays;}
  @PostMapping("/login") public ResponseEntity<?> login(@Valid @RequestBody AuthLoginRequest body,HttpServletResponse response){try{return session(auth.login(body),response);}catch(IllegalArgumentException error){return ResponseEntity.status(401).build();}}
  @PostMapping("/refresh") public ResponseEntity<?> refresh(HttpServletRequest request,HttpServletResponse response){try{return session(auth.refresh(refreshRequest(request)),response);}catch(IllegalArgumentException error){clear(response);return ResponseEntity.status(401).build();}}
  @PostMapping({"/logout","/revoke"}) public ResponseEntity<Void> logout(HttpServletRequest request,HttpServletResponse response){try{auth.revoke(refreshRequest(request));}catch(IllegalArgumentException ignored){}finally{clear(response);}return ResponseEntity.noContent().build();}
  private ResponseEntity<?> session(AuthTokenResponse tokens,HttpServletResponse response){
    cookie(response,ACCESS,tokens.getAccessToken(),"/",Duration.ofSeconds(tokens.getExpiresIn()));
    cookie(response,REFRESH,tokens.getRefreshToken(),"/",Duration.ofDays(refreshDays));
    return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(java.util.Map.of("expiresIn",tokens.getExpiresIn()));
  }
  private AuthRefreshRequest refreshRequest(HttpServletRequest request){var body=new AuthRefreshRequest();body.setRefreshToken(cookieValue(request,secure?REFRESH:REFRESH.replace("__Host-","")));if(body.getRefreshToken()==null)throw new IllegalArgumentException("Session missing");return body;}
  private void clear(HttpServletResponse response){cookie(response,ACCESS,"","/",Duration.ZERO);cookie(response,REFRESH,"","/",Duration.ZERO);}
  private void cookie(HttpServletResponse response,String name,String value,String path,Duration age){response.addHeader(HttpHeaders.SET_COOKIE,ResponseCookie.from(secure?name:name.replace("__Host-",""),value).httpOnly(true).secure(secure).sameSite("Strict").path(path).maxAge(age).build().toString());}
  public static String cookieValue(HttpServletRequest request,String name){if(request.getCookies()!=null)for(Cookie cookie:request.getCookies())if(cookie.getName().equals(name))return cookie.getValue();return null;}
}

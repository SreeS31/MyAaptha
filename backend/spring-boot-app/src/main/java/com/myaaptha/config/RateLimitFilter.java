package com.myaaptha.config;

import com.myaaptha.platform.state.EphemeralState;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class RateLimitFilter extends OncePerRequestFilter {
  private final EphemeralState state;
  @org.springframework.beans.factory.annotation.Autowired private com.myaaptha.platform.security.SecurityIncidentService incidents;
  private final int authLimit,apiLimit;
  private final boolean trustForwardedFor;
  public RateLimitFilter(EphemeralState state,@Value("${myaaptha.rate-limit.auth-per-minute:20}") int authLimit,
      @Value("${myaaptha.rate-limit.api-per-minute:300}") int apiLimit,
      @Value("${myaaptha.rate-limit.trust-forwarded-for:false}") boolean trustForwardedFor) {
    if(trustForwardedFor)throw new IllegalArgumentException("Use native forwarding with explicitly trusted proxies; raw X-Forwarded-For is unsafe");
    this.state=state;this.authLimit=authLimit;this.apiLimit=apiLimit;this.trustForwardedFor=false;
  }
  protected boolean shouldNotFilter(HttpServletRequest request) {
    return !request.getRequestURI().startsWith("/api/")||"OPTIONS".equals(request.getMethod());
  }
  protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws IOException,ServletException {
    String path=request.getRequestURI();
    boolean auth=path.startsWith("/api/web-auth/")||java.util.Set.of("/api/auth/phone/start","/api/auth/reset-password","/api/auth/login","/api/auth/refresh","/api/auth/logout","/api/auth/revoke").contains(path)||("POST".equals(request.getMethod())&&path.equals("/api/users"));
    int limit=auth?authLimit:apiLimit;String ip=request.getRemoteAddr();
    var principal=org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
    String subject=!auth&&principal!=null&&principal.isAuthenticated()?"user:"+principal.getName():"ip:"+ip;
    long count;
    boolean administrator=principal!=null&&principal.getAuthorities().stream().anyMatch(a->a.getAuthority().equals("ROLE_ADMIN"));
    try {
      if(state.get("security:block:"+ip)!=null&&!(administrator&&(path.startsWith("/api/admin/security")||path.equals("/api/auth/me")))){response.setStatus(403);response.setContentType("application/json");response.getWriter().write("{\"message\":\"Access temporarily blocked following a security incident\"}");return;}
      if(request.getContentType()!=null&&request.getContentType().toLowerCase(java.util.Locale.ROOT).startsWith("multipart/")){
        long uploads=state.increment("upload:ip:"+ip,Duration.ofMinutes(1));
        long userUploads=state.increment("upload:"+subject,Duration.ofMinutes(1));
        if(uploads>60||userUploads>20){response.setStatus(429);response.setHeader("Retry-After","60");response.setContentType("application/json");response.getWriter().write("{\"message\":\"Too many uploads. Please wait a minute.\"}");return;}
        if(request.getContentLengthLong()>30L*1024*1024){response.setStatus(413);return;}
      }
    }catch(RuntimeException error){response.setStatus(503);return;}

    try {count=state.increment("rate:"+(auth?"auth:":"api:")+subject,Duration.ofMinutes(1));}
    catch(RuntimeException error){response.setStatus(503);response.setHeader("Retry-After","5");response.setContentType("application/json");response.getWriter().write("{\"message\":\"Request protection is temporarily unavailable\"}");return;}
    response.setHeader("X-RateLimit-Limit",String.valueOf(limit));
    response.setHeader("X-RateLimit-Remaining",String.valueOf(Math.max(0,limit-count)));
    if(count>limit){response.setStatus(429);response.setHeader("Retry-After","60");response.setContentType("application/json");response.getWriter().write("{\"message\":\"Too many requests. Please wait a minute and try again.\"}");return;}
    try{chain.doFilter(request,response);}finally{
      if(response.getStatus()>=500&&incidents!=null)try{incidents.recordRequest(request,"SERVER_ERROR","Server request failed (HTTP "+response.getStatus()+")",false);}catch(RuntimeException error){org.slf4j.LoggerFactory.getLogger(getClass()).error("Could not record server error incident");}
    }
  }
}

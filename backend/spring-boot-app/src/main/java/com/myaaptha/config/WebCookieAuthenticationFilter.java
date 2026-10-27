package com.myaaptha.config;

import com.myaaptha.domain.auth.WebSessionController;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Cookie authentication is accepted only with CSRF-protected browser mutations. */
@Component
public class WebCookieAuthenticationFilter extends OncePerRequestFilter {
  private final Set<String> origins;private final boolean secure;
  public WebCookieAuthenticationFilter(@Value("${myaaptha.cors.allowed-origins:http://localhost:3000,http://127.0.0.1:3000}") String allowed,@Value("${security.web-cookie.secure:true}") boolean secure){this.secure=secure;origins=new HashSet<>(Arrays.asList(allowed.split(",")));}
  protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws IOException,ServletException{
    String access=WebSessionController.cookieValue(request,secure?WebSessionController.ACCESS:WebSessionController.ACCESS.replace("__Host-",""));
    boolean web=request.getRequestURI().startsWith("/api/web-auth/")||access!=null||WebSessionController.cookieValue(request,secure?WebSessionController.REFRESH:WebSessionController.REFRESH.replace("__Host-",""))!=null;
    boolean safe=Set.of("GET","HEAD","OPTIONS").contains(request.getMethod());
    if(web&&!safe&&(!"1".equals(request.getHeader("X-MyAaptha-Web"))||!origins.contains(request.getHeader("Origin")))){response.setStatus(403);return;}
    if(access==null||request.getHeader("Authorization")!=null){chain.doFilter(request,response);return;}
    final String token=access;
    var wrapped=new HttpServletRequestWrapper(request){
      public String getHeader(String name){return "Authorization".equalsIgnoreCase(name)?"Bearer "+token:super.getHeader(name);}
      public Enumeration<String> getHeaders(String name){return "Authorization".equalsIgnoreCase(name)?Collections.enumeration(List.of("Bearer "+token)):super.getHeaders(name);}
      public Enumeration<String> getHeaderNames(){var names=Collections.list(super.getHeaderNames());names.add("Authorization");return Collections.enumeration(names);}
    };
    chain.doFilter(wrapped,response);
  }
}

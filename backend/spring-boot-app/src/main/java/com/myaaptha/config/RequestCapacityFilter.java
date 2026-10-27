package com.myaaptha.config;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.util.concurrent.Semaphore;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Fail quickly instead of allowing expensive requests to exhaust threads/heap. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE+20)
public class RequestCapacityFilter extends OncePerRequestFilter {
  private final Semaphore all, uploads;
  public RequestCapacityFilter(@Value("${myaaptha.capacity.requests:100}") int requests,
      @Value("${myaaptha.capacity.uploads:4}") int files) {
    if(requests<1||files<1) throw new IllegalArgumentException("Request capacities must be positive");
    all=new Semaphore(requests);uploads=new Semaphore(files);
  }
  protected boolean shouldNotFilter(HttpServletRequest request){return !request.getRequestURI().startsWith("/api/");}
  protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws IOException,ServletException {
    boolean multipart=request.getContentType()!=null&&request.getContentType().startsWith("multipart/");
    if(!all.tryAcquire()){busy(response);return;}
    boolean fileAcquired=false;
    try {
      if(multipart){fileAcquired=uploads.tryAcquire();if(!fileAcquired){busy(response);return;}}
      chain.doFilter(request,response);
    } finally { if(fileAcquired)uploads.release();all.release(); }
  }
  private void busy(HttpServletResponse response)throws IOException {
    response.setStatus(503);response.setHeader("Retry-After","5");response.setContentType("application/json");
    response.getWriter().write("{\"message\":\"Service is busy. Please retry shortly.\"}");
  }
}

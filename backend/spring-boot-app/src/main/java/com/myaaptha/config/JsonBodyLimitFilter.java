package com.myaaptha.config;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Bound JSON before deserialization, including requests with no Content-Length. */
@Component @Order(Ordered.HIGHEST_PRECEDENCE+10)
public class JsonBodyLimitFilter extends OncePerRequestFilter {
  private final long limit;
  public JsonBodyLimitFilter(@Value("${myaaptha.capacity.json-bytes:1048576}") long limit){if(limit<1)throw new IllegalArgumentException("JSON limit must be positive");this.limit=limit;}
  protected boolean shouldNotFilter(HttpServletRequest request){String type=request.getContentType();return !request.getRequestURI().startsWith("/api/")||type==null||!type.toLowerCase(java.util.Locale.ROOT).contains("json");}
  protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws ServletException,IOException{
    if(request.getContentLengthLong()>limit){reject(response);return;}
    var wrapped=new HttpServletRequestWrapper(request){
      private ServletInputStream bounded;
      public ServletInputStream getInputStream()throws IOException{
        if(bounded!=null)return bounded;
        var source=super.getInputStream();
        bounded=new ServletInputStream(){
          long count;
          private void count(int amount)throws IOException{if(amount>0){count+=amount;if(count>limit)throw new BodyTooLargeException();}}
          public int read()throws IOException{int value=source.read();if(value!=-1)count(1);return value;}
          public int read(byte[] data,int offset,int length)throws IOException{int value=source.read(data,offset,(int)Math.min(length,limit-count+1));count(value);return value;}
          public boolean isFinished(){return source.isFinished();}
          public boolean isReady(){return source.isReady();}
          public void setReadListener(ReadListener listener){source.setReadListener(listener);}
          public void close()throws IOException{source.close();}
        };return bounded;
      }
      public BufferedReader getReader()throws IOException{return new BufferedReader(new InputStreamReader(getInputStream(),getCharacterEncoding()==null?"UTF-8":getCharacterEncoding()));}
    };
    try{chain.doFilter(wrapped,response);}catch(BodyTooLargeException error){reject(response);}
  }
  private void reject(HttpServletResponse response)throws IOException{response.setStatus(413);response.setContentType("application/json");response.getWriter().write("{\"message\":\"JSON request exceeds the size limit\"}");}
  public static class BodyTooLargeException extends IOException {}
}

package com.myaaptha.platform.audit;
import jakarta.servlet.http.*; import org.springframework.stereotype.Component; import org.springframework.web.servlet.HandlerInterceptor;
@Component public class AuditInterceptor implements HandlerInterceptor{
 private final AuditEventRepository events; public AuditInterceptor(AuditEventRepository events){this.events=events;}
 @Override public void afterCompletion(HttpServletRequest request,HttpServletResponse response,Object handler,Exception ex){String method=request.getMethod();if(!method.matches("POST|PUT|PATCH|DELETE"))return;try{AuditEventEntity e=new AuditEventEntity();if(request.getUserPrincipal()!=null)try{e.setActorUserId(Long.valueOf(request.getUserPrincipal().getName()));}catch(NumberFormatException ignored){}e.setAction(method);e.setRequestPath(request.getRequestURI());String[] parts=request.getRequestURI().split("/");if(parts.length>3)e.setResourceType(parts[3]);if(parts.length>4)e.setResourceId(parts[4]);e.setResponseStatus(response.getStatus());e.setIpAddress(clientIp(request));e.setUserAgent(limit(request.getHeader("User-Agent"),500));events.save(e);}catch(Exception ignored){}
 }
 private String clientIp(HttpServletRequest request){String forwarded=request.getHeader("X-Forwarded-For");return forwarded==null?request.getRemoteAddr():forwarded.split(",")[0].trim();} private String limit(String v,int max){return v==null?null:v.substring(0,Math.min(v.length(),max));}
}

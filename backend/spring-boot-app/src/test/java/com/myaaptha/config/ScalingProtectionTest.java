package com.myaaptha.config;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.myaaptha.platform.state.*;
import java.time.Duration;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

class ScalingProtectionTest {
  @Test void sharedCountersAreAtomicAcrossWorkers() throws Exception {
    var state=new LocalEphemeralState();
    try(var executor=Executors.newFixedThreadPool(8)){
      var tasks=new java.util.ArrayList<Future<Long>>();
      for(int i=0;i<1000;i++)tasks.add(executor.submit(()->state.increment("shared",Duration.ofMinutes(1))));
      var values=new java.util.HashSet<Long>();for(var task:tasks)values.add(task.get());
      assertEquals(1000,values.size());assertTrue(values.contains(1000L));
    }
  }
  @Test void replicasShareUserBudgetAndUsersBehindOneProxyRemainIndependent() throws Exception {
    var state=new LocalEphemeralState();var first=new RateLimitFilter(state,2,2,false);var second=new RateLimitFilter(state,2,2,false);
    try {
      SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken("101",null,java.util.List.of()));
      assertEquals(200,request(first));assertEquals(200,request(second));assertEquals(429,request(first));
      SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken("102",null,java.util.List.of()));
      assertEquals(200,request(second));
    } finally {SecurityContextHolder.clearContext();}
  }
  @Test void unavailableSharedProtectionFailsClosed() throws Exception {
    var state=mock(EphemeralState.class);when(state.increment(anyString(),any())).thenThrow(new IllegalStateException());
    assertEquals(503,request(new RateLimitFilter(state,2,2,false)));
  }
  @Test void forwardedHeaderCannotCreateNewAnonymousBudgets()throws Exception{
    var filter=new RateLimitFilter(new LocalEphemeralState(),1,2,false);
    for(int i=0;i<2;i++){
      var request=new MockHttpServletRequest("POST","/api/users");request.addHeader("X-Forwarded-For","192.0.2."+i);
      var response=new MockHttpServletResponse();filter.doFilter(request,response,(a,b)->{});assertEquals(i==0?200:429,response.getStatus());
    }
    assertThrows(IllegalArgumentException.class,()->new RateLimitFilter(new LocalEphemeralState(),1,2,true));
  }
  @Test void jsonLimitRejectsDeclaredAndStreamingOversizedBodies()throws Exception{
    var filter=new JsonBodyLimitFilter(16);
    for(boolean chunked:new boolean[]{false,true}){
      var request=new MockHttpServletRequest("POST","/api/users"){@Override public long getContentLengthLong(){return chunked?-1:32;}};
      request.setContentType("application/json");request.setContent(new byte[32]);var response=new MockHttpServletResponse();
      filter.doFilter(request,response,(a,b)->a.getInputStream().readAllBytes());assertEquals(413,response.getStatus());
    }
  }
  private int request(RateLimitFilter filter)throws Exception{
    var request=new MockHttpServletRequest("GET","/api/network/circles");var response=new MockHttpServletResponse();
    filter.doFilter(request,response,(a,b)->{});return response.getStatus();
  }
  @Test void overloadRejectsQuicklyButHealthWorksAndPermitsRecoverAfterFailure() throws Exception {
    var filter=new RequestCapacityFilter(1,1);var request=new MockHttpServletRequest("GET","/api/work");
    assertThrows(jakarta.servlet.ServletException.class,()->filter.doFilter(request,new MockHttpServletResponse(),(a,b)->{
      var rejected=new MockHttpServletResponse();filter.doFilter(new MockHttpServletRequest("GET","/api/work"),rejected,(x,y)->fail("Overload must not enter application"));
      assertEquals(503,rejected.getStatus());assertEquals("5",rejected.getHeader("Retry-After"));
      filter.doFilter(new MockHttpServletRequest("GET","/actuator/health/liveness"),new MockHttpServletResponse(),(x,y)->{});
      throw new jakarta.servlet.ServletException("simulated failure");
    }));
    var response=new MockHttpServletResponse();filter.doFilter(new MockHttpServletRequest("GET","/api/work"),response,(a,b)->{});assertEquals(200,response.getStatus());
  }
}

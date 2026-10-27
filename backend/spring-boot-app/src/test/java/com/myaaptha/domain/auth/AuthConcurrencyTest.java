package com.myaaptha.domain.auth;
import static org.junit.jupiter.api.Assertions.*;
import com.myaaptha.domain.auth.dto.*;
import com.myaaptha.domain.user.*;
import com.myaaptha.domain.user.model.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
@SpringBootTest
class AuthConcurrencyTest {
 @Autowired AuthService auth; @Autowired UserRepository users; @Autowired AuthTokenRepository tokens;
 @Autowired org.springframework.security.crypto.password.PasswordEncoder encoder;
 @Test void onlyOneConcurrentRefreshCanConsumeAToken()throws Exception{
   var user=new UserEntity();user.setUsername("refresh-"+java.util.UUID.randomUUID());user.setPasswordHash(encoder.encode("testPassword123!"));user=users.save(user);
   var login=new AuthLoginRequest();login.setIdentifier(user.getUsername());login.setPassword("testPassword123!");
   var session=auth.login(login);var request=new AuthRefreshRequest();request.setRefreshToken(session.getRefreshToken());
   try(var executor=java.util.concurrent.Executors.newFixedThreadPool(2)){
     var ready=new java.util.concurrent.CountDownLatch(2);var start=new java.util.concurrent.CountDownLatch(1);
     java.util.concurrent.Callable<Boolean> attempt=()->{ready.countDown();start.await();try{auth.refresh(request);return true;}catch(IllegalArgumentException expected){return false;}};
     var first=executor.submit(attempt);var second=executor.submit(attempt);ready.await();start.countDown();
     assertNotEquals(first.get(),second.get(),"Exactly one refresh may succeed");
   }
 }
 @Test void suspendedAccountCannotRefresh(){
   var user=new UserEntity();user.setUsername("suspended-"+java.util.UUID.randomUUID());user.setPasswordHash(encoder.encode("testPassword123!"));user=users.save(user);
   var login=new AuthLoginRequest();login.setIdentifier(user.getUsername());login.setPassword("testPassword123!");var session=auth.login(login);
   user.setAccountStatus("SUSPENDED");users.saveAndFlush(user);var request=new AuthRefreshRequest();request.setRefreshToken(session.getRefreshToken());
   assertThrows(IllegalArgumentException.class,()->auth.refresh(request));
 }
}

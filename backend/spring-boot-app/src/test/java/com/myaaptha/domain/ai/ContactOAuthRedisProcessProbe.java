package com.myaaptha.domain.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.myaaptha.platform.state.RedisEphemeralState;
import java.nio.charset.StandardCharsets;
import java.util.*;
import org.springframework.data.redis.connection.*;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.util.UriComponentsBuilder;

/** Synthetic subprocess fixture: never exchanges codes or calls an external provider. */
public final class ContactOAuthRedisProcessProbe {
  public static void main(String[] args) throws Exception {
    var config=new RedisStandaloneConfiguration(System.getenv("REDIS_TEST_HOST"),Integer.parseInt(System.getenv().getOrDefault("REDIS_TEST_PORT","6379")));
    String password=System.getenv("REDIS_TEST_PASSWORD");if(password!=null)config.setPassword(RedisPassword.of(password));
    var connection=new LettuceConnectionFactory(config);connection.afterPropertiesSet();
    try {
      var backing=new RedisEphemeralState(new StringRedisTemplate(connection),System.getenv("OAUTH_TEST_NAMESPACE"));
      var service=new ContactOAuthService("http://unused","http://localhost:8080","http://localhost:3000","synthetic-id","synthetic-secret","synthetic-id","synthetic-secret",null,null,ContactOAuthTestSupport.store(backing));
      var json=new ObjectMapper();Object output;
      if(args[0].equals("start")) {
        var start=service.start(42L,new ContactOAuthService.StartRequest("synthetic@example.test","google"));
        String state=UriComponentsBuilder.fromUriString(start.authorizationUrl()).build().getQueryParams().getFirst("state");
        output=Map.of("state",state,"resultKey",start.resultKey());
      } else {
        Map<?,?> input=json.readValue(System.in.readAllBytes(),Map.class);
        if(args[0].equals("callback")) {
          service.callback("microsoft",null,input.get("state").toString(),"access_denied");
          service.callback("google",null,input.get("state").toString(),"access_denied");
          output="callback-ok";
        } else if(args[0].equals("consume")) {
          String key=input.get("resultKey").toString();
          expectStatus(404,()->service.consumeOrganizer(43L,key));
          expectStatus(422,()->service.consumeOrganizer(42L,key));
          expectStatus(404,()->service.consumeOrganizer(42L,key));
          output="verified";
        } else {
          service.callback("google",null,input.get("state").toString(),"access_denied");
          expectStatus(404,()->service.consumeOrganizer(42L,input.get("resultKey").toString()));
          output="replay-rejected";
        }
      }
      System.out.println("OAUTH_TEST_RESULT:"+Base64.getEncoder().encodeToString(json.writeValueAsBytes(output)));
    } finally { connection.destroy(); }
  }
  private static void expectStatus(int expected,Runnable action) {
    try {action.run();throw new AssertionError("Expected HTTP status "+expected);}
    catch(ResponseStatusException error) {if(error.getStatusCode().value()!=expected)throw new AssertionError("Unexpected HTTP status");}
  }
}

package com.myaaptha.domain.ai;

import static org.junit.jupiter.api.Assertions.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

@EnabledIfEnvironmentVariable(named="REDIS_TEST_HOST",matches=".+")
class ContactOAuthSharedRedisTest {
  @Test void separateJvmLifetimesCanStartCallbackConsumeAndRejectReplay() throws Exception {
    String namespace="oauth-process-test:"+UUID.randomUUID();
    Map<?,?> started=(Map<?,?>)probe("start",namespace,Map.of());
    assertEquals("callback-ok",probe("callback",namespace,started));
    assertEquals("verified",probe("consume",namespace,started));
    assertEquals("replay-rejected",probe("replay",namespace,started));
  }

  private Object probe(String phase,String namespace,Object input) throws Exception {
    String java=Path.of(System.getProperty("java.home"),"bin",System.getProperty("os.name").startsWith("Windows")?"java.exe":"java").toString();
    String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));
    var builder=new ProcessBuilder(java,"-cp",classpath,ContactOAuthRedisProcessProbe.class.getName(),phase).redirectErrorStream(true);
    builder.environment().put("OAUTH_TEST_NAMESPACE",namespace);
    var process=builder.start();
    try {
      process.getOutputStream().write(new ObjectMapper().writeValueAsBytes(input));process.getOutputStream().close();
      if(!process.waitFor(45,TimeUnit.SECONDS)) throw new AssertionError("Synthetic OAuth subprocess timed out");
      String output=new String(process.getInputStream().readAllBytes(),StandardCharsets.UTF_8);
      // Do not include opaque tokens or payloads in failure output.
      assertEquals(0,process.exitValue(),"Synthetic OAuth subprocess failed in phase "+phase);
      String encoded=output.lines().filter(line->line.startsWith("OAUTH_TEST_RESULT:")).map(line->line.substring("OAUTH_TEST_RESULT:".length())).findFirst().orElseThrow();
      return new ObjectMapper().readValue(Base64.getDecoder().decode(encoded),Object.class);
    } finally { if(process.isAlive()) process.destroyForcibly(); }
  }
}

package com.myaaptha.config;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Optional machine credential scoped to a single read-only metrics endpoint. */
@Component
public class MetricsScrapeCredential {
  private final byte[] expected;
  public MetricsScrapeCredential(@Value("${security.metrics.scrape-token:}") String token) {
    if(token==null || token.isBlank()) {expected=null;return;}
    int bytes=token.getBytes(StandardCharsets.UTF_8).length;
    if(bytes<32 || bytes>512) throw new IllegalStateException("Metrics scrape credential must contain 32 to 512 UTF-8 bytes");
    expected=digest(token);
  }
  public boolean accepts(String method,String path,String token) {
    return expected!=null && "GET".equals(method) && "/actuator/prometheus".equals(path)
        && token!=null && MessageDigest.isEqual(expected,digest(token));
  }
  private byte[] digest(String token) {
    try {return MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));}
    catch(java.security.NoSuchAlgorithmException error) {throw new IllegalStateException("Metrics credential validation unavailable");}
  }
}

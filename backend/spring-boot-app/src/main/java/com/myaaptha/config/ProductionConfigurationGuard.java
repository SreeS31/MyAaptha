package com.myaaptha.config;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/** Refuse known development credentials and incomplete production configuration. */
@Component
@Profile("prod")
public class ProductionConfigurationGuard {
  public ProductionConfigurationGuard(Environment env) {
    if (!env.getProperty("security.fields.enabled", Boolean.class, false)) throw new IllegalStateException("Production requires sensitive-field encryption");
    if (env.getProperty("security.fields.allow-legacy-reads", Boolean.class, false)) throw new IllegalStateException("Migrate plaintext fields before starting production");
    if (!env.getProperty("security.admin-mfa.required", Boolean.class, false)) throw new IllegalStateException("Production requires administrator MFA");
    if (!env.getProperty("security.web-cookie.secure", Boolean.class, true)) throw new IllegalStateException("Production cookies must be secure");
    if (!env.getProperty("spring.data.redis.ssl.enabled", Boolean.class, false)) throw new IllegalStateException("Production Redis connections require TLS");
    if (!required(env, "spring.datasource.url").matches(".*[?&]sslmode=verify-full(?:&.*)?$")) throw new IllegalStateException("Production database connections require certificate and hostname verification");
    try { if (java.util.Base64.getDecoder().decode(required(env, "ADMIN_MFA_ENCRYPTION_KEY")).length != 32) throw new IllegalArgumentException(); }
    catch (IllegalArgumentException error) { throw new IllegalStateException("Configure a 32-byte Base64 administrator MFA key"); }
    String proxies=required(env,"server.tomcat.remoteip.internal-proxies");
    if(placeholder(proxies)||proxies.equals(".*")||proxies.equals(".+"))throw new IllegalStateException("Specify only trusted proxy addresses");
    try {java.util.regex.Pattern.compile(proxies);}catch(java.util.regex.PatternSyntaxException error){throw new IllegalStateException("Invalid trusted proxy expression");}

    if (!"redis".equals(env.getProperty("myaaptha.state.provider"))) {
      throw new IllegalStateException("Production requires shared Redis state for rate limiting and presence");
    }
    required(env, "spring.data.redis.host");
    String redisPassword=required(env, "spring.data.redis.password");
    if(redisPassword.length()<16||placeholder(redisPassword)) throw new IllegalStateException("Configure a strong Redis credential");
    String secret = required(env, "security.jwt.secret");
    if (secret.getBytes(StandardCharsets.UTF_8).length < 32 || placeholder(secret)) {
      throw new IllegalStateException("Production JWT secret must be random, at least 32 bytes, and not a placeholder");
    }
    String password = required(env, "spring.datasource.password");
    if (password.length() < 16 || placeholder(password)) {
      throw new IllegalStateException("Production database password must be at least 16 characters and not a placeholder");
    }
    if (!"clamav".equals(env.getProperty("myaaptha.storage.scanner"))) throw new IllegalStateException("Production requires antivirus scanning");
    String storage = env.getProperty("myaaptha.storage.provider");
    if (!java.util.Set.of("s3", "gcs").contains(storage == null ? "" : storage)) {
      throw new IllegalStateException("Production requires durable S3-compatible or Google Cloud storage");
    }
    String bucket = required(env, "myaaptha.storage." + storage + ".bucket");
    if (placeholder(bucket) || ("gcs".equals(storage) && !bucket.matches("[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]"))) {
      throw new IllegalStateException("Configure a real production storage bucket");
    }
    https(required(env, "myaaptha.contact-oauth.public-api-base-url"));
    https(required(env, "myaaptha.contact-oauth.web-origin"));
    for (String origin : required(env, "myaaptha.cors.allowed-origins").split(",")) https(origin.trim());
    if (!"validate".equals(env.getProperty("spring.jpa.hibernate.ddl-auto"))) {
      throw new IllegalStateException("Production requires schema validation and versioned migrations");
    }
  }

  private static String required(Environment env, String key) {
    String value = env.getProperty(key);
    if (value == null || value.isBlank()) throw new IllegalStateException("Missing production configuration: " + key);
    return value;
  }

  private static boolean placeholder(String value) {
    String lower = value.toLowerCase(Locale.ROOT);
    return lower.contains("replace") || lower.contains("dummy") || lower.contains("change-me")
        || lower.contains("changethis") || lower.contains("local-dev") || lower.contains("example")
        || lower.equals("myaaptha123") || lower.equals("admin123");
  }

  private static void https(String value) {
    URI uri;
    try { uri = URI.create(value); } catch (IllegalArgumentException ex) {
      throw new IllegalStateException("Production public URLs must be valid HTTPS origins");
    }
    if (!"https".equals(uri.getScheme()) || uri.getHost() == null || uri.getUserInfo() != null
        || uri.getQuery() != null || uri.getFragment() != null
        || !(uri.getPath().isEmpty() || uri.getPath().equals("/"))
        || uri.getHost().equals("localhost") || uri.getHost().endsWith(".invalid") || placeholder(uri.getHost())) {
      throw new IllegalStateException("Production public URLs must be real HTTPS origins without paths");
    }
  }
}

package com.myaaptha.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import static org.junit.jupiter.api.Assertions.*;

class ProductionConfigurationGuardTest {
  private MockEnvironment valid() {
    return new MockEnvironment().withProperty("myaaptha.storage.scanner","clamav").withProperty("server.tomcat.remoteip.internal-proxies","127[.]0[.]0[.]1")
        .withProperty("security.fields.enabled", "true")
        .withProperty("security.fields.allow-legacy-reads", "false")
        .withProperty("security.admin-mfa.required", "true")
        .withProperty("security.web-cookie.secure", "true")
        .withProperty("spring.data.redis.ssl.enabled", "true")
        .withProperty("spring.datasource.url", "jdbc:postgresql://db.myaaptha.test/myaaptha?sslmode=verify-full")
        .withProperty("ADMIN_MFA_ENCRYPTION_KEY", "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=")
        .withProperty("myaaptha.state.provider", "redis")
        .withProperty("spring.data.redis.host", "cache.myaaptha.test")
        .withProperty("spring.data.redis.password", "2e2696a89ad542ef8b0cac5af71e62d2")
        .withProperty("security.jwt.secret", "7f23428d886746718d76bfa1959c306d8baf93271a75ef38")
        .withProperty("spring.datasource.password", "9d14e75cae894ff3ac7984257a9e81d4")
        .withProperty("spring.jpa.hibernate.ddl-auto", "validate")
        .withProperty("myaaptha.storage.provider", "s3")
        .withProperty("myaaptha.storage.s3.bucket", "myaaptha-staging-media")
        .withProperty("myaaptha.contact-oauth.public-api-base-url", "https://app.myaaptha.test")
        .withProperty("myaaptha.contact-oauth.web-origin", "https://app.myaaptha.test")
        .withProperty("myaaptha.cors.allowed-origins", "https://app.myaaptha.test");
  }
  @Test void acceptsCompleteConfiguration() { assertDoesNotThrow(() -> new ProductionConfigurationGuard(valid())); }
  @Test void acceptsPrivateGcsConfigurationAndRejectsMissingBucket() {
    var gcs = valid().withProperty("myaaptha.storage.provider", "gcs")
        .withProperty("myaaptha.storage.gcs.bucket", "myaaptha-beta-private-media");
    assertDoesNotThrow(() -> new ProductionConfigurationGuard(gcs));
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(
        gcs.withProperty("myaaptha.storage.gcs.bucket", "")));
  }
  @Test void rejectsDevelopmentSecret() {
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid()
        .withProperty("security.jwt.secret", "myaaptha-local-dev-jwt-secret-please-change-2026-strong")));
  }
  @Test void rejectsDummyDomain() {
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid()
        .withProperty("myaaptha.cors.allowed-origins", "https://app.example.com")));
  }
  @Test void rejectsSchemaMutation() {
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid()
        .withProperty("spring.jpa.hibernate.ddl-auto", "update")));
  }
  @Test void rejectsLocalStorage() {
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid()
        .withProperty("myaaptha.storage.provider", "local")));
  }
  @Test void rejectsDisabledEncryptionAndLegacyPlaintextReads() {
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid().withProperty("security.fields.enabled", "false")));
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid().withProperty("security.fields.allow-legacy-reads", "true")));
  }
  @Test void rejectsInsecureTransportAndMissingMfa() {
    for (String setting : new String[]{"security.admin-mfa.required", "security.web-cookie.secure", "spring.data.redis.ssl.enabled"}) {
      assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid().withProperty(setting, "false")));
    }
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid().withProperty("spring.datasource.url", "jdbc:postgresql://db.myaaptha.test/myaaptha?sslmode=require")));
    assertThrows(IllegalStateException.class, () -> new ProductionConfigurationGuard(valid().withProperty("ADMIN_MFA_ENCRYPTION_KEY", "invalid")));
  }
}

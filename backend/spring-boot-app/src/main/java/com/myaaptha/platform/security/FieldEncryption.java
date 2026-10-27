package com.myaaptha.platform.security;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/** Versioned authenticated encryption. Keys stay outside the database and are decoded once. */
@Component
public class FieldEncryption {
  private static final String PREFIX = "enc:v1:";
  private final Map<String, SecretKeySpec> keys = new HashMap<>();
  private final SecureRandom random = new SecureRandom();
  private final String activeId;
  private final boolean enabled;
  private final boolean legacyReads;

  public FieldEncryption(Environment environment) {
    enabled = environment.getProperty("security.fields.enabled", Boolean.class, false);
    legacyReads = environment.getProperty("security.fields.allow-legacy-reads", Boolean.class, false);
    activeId = environment.getProperty("security.fields.active-key-id", "primary");
    if (!activeId.matches("[A-Za-z0-9_-]{1,32}")) throw new IllegalStateException("Invalid field encryption key ID");
    String configured = environment.getProperty("security.fields.keys", "");
    if (!configured.isBlank()) for (String entry : configured.split(",")) {
      String[] parts = entry.trim().split("=", 2);
      if (parts.length != 2 || !parts[0].matches("[A-Za-z0-9_-]{1,32}")) throw new IllegalStateException("Invalid field encryption key configuration");
      try {
        byte[] bytes = Base64.getDecoder().decode(parts[1]);
        if (bytes.length != 32 || keys.containsKey(parts[0])) throw new IllegalArgumentException();
        keys.put(parts[0], new SecretKeySpec(bytes, "AES"));
        Arrays.fill(bytes, (byte) 0);
      } catch (IllegalArgumentException error) { throw new IllegalStateException("Field encryption keys must be unique IDs and Base64-encoded 32-byte keys"); }
    }
    if (enabled && !keys.containsKey(activeId)) throw new IllegalStateException("The active field encryption key is missing");
  }

  public boolean isEnabled() { return enabled; }

  public String encrypt(String value) {
    if (value == null || !enabled) return value;
    try {
      byte[] nonce = new byte[12]; random.nextBytes(nonce);
      String header = PREFIX + activeId + ":";
      Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
      cipher.init(Cipher.ENCRYPT_MODE, keys.get(activeId), new GCMParameterSpec(128, nonce));
      cipher.updateAAD(header.getBytes(StandardCharsets.UTF_8));
      byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
      return header + Base64.getEncoder().encodeToString(ByteBuffer.allocate(nonce.length + encrypted.length).put(nonce).put(encrypted).array());
    } catch (GeneralSecurityException error) { throw new IllegalStateException("Sensitive data encryption failed"); }
  }

  public String decrypt(String value) {
    if (value == null) return null;
    if (!value.startsWith("enc:")) {
      if (!enabled || legacyReads) return value;
      throw new IllegalStateException("Sensitive data migration is required");
    }
    try {
      if (!value.startsWith(PREFIX)) throw new IllegalArgumentException();
      int end = value.indexOf(':', PREFIX.length());
      if (end < 0) throw new IllegalArgumentException();
      String header = value.substring(0, end + 1);
      SecretKeySpec key = keys.get(value.substring(PREFIX.length(), end));
      if (key == null) throw new IllegalArgumentException();
      byte[] bytes = Base64.getDecoder().decode(value.substring(end + 1));
      if (bytes.length < 28) throw new IllegalArgumentException();
      Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
      cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, Arrays.copyOf(bytes, 12)));
      cipher.updateAAD(header.getBytes(StandardCharsets.UTF_8));
      return new String(cipher.doFinal(Arrays.copyOfRange(bytes, 12, bytes.length)), StandardCharsets.UTF_8);
    } catch (GeneralSecurityException | IllegalArgumentException error) {
      // Never log ciphertext, plaintext, or key material, or return corrupt data as plaintext.
      throw new IllegalStateException("Sensitive data could not be authenticated");
    }
  }
}

package com.myaaptha.platform.security;

import static org.junit.jupiter.api.Assertions.*;
import java.util.Base64;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class FieldEncryptionTest {
  static String key(int marker) { byte[] bytes = new byte[32]; java.util.Arrays.fill(bytes, (byte) marker); return Base64.getEncoder().encodeToString(bytes); }
  static FieldEncryption encryption(String id, String keys, boolean legacy) {
    return new FieldEncryption(new MockEnvironment().withProperty("security.fields.enabled", "true")
        .withProperty("security.fields.active-key-id", id).withProperty("security.fields.keys", keys)
        .withProperty("security.fields.allow-legacy-reads", Boolean.toString(legacy)));
  }
  @Test void randomNoncesRoundTripNullEmptyUnicodeAndDecimals() {
    var cipher = encryption("a", "a=" + key(1), false);
    for (String value : new String[]{"", "private medical note", "नमस्ते"}) {
      String encrypted = cipher.encrypt(value);
      assertEquals(value, cipher.decrypt(encrypted));
      assertNotEquals(encrypted, cipher.encrypt(value));
      if (!value.isEmpty()) assertFalse(encrypted.contains(value));
    }
    assertNull(cipher.decrypt(cipher.encrypt(null)));
    var decimals = new EncryptedDecimalConverter(cipher);
    assertEquals(new BigDecimal("12345.6700"), decimals.convertToEntityAttribute(decimals.convertToDatabaseColumn(new BigDecimal("12345.6700"))));
  }
  @Test void rejectsTamperingWrongKeysPlaintextAndMissingKey() {
    var cipher = encryption("a", "a=" + key(1), false);
    String value = cipher.encrypt("secret");
    assertThrows(IllegalStateException.class, () -> cipher.decrypt(value.substring(0, value.length() - 4) + "AAAA"));
    assertThrows(IllegalStateException.class, () -> encryption("a", "a=" + key(2), false).decrypt(value));
    assertThrows(IllegalStateException.class, () -> cipher.decrypt("plaintext"));
    assertThrows(IllegalStateException.class, () -> encryption("a", "", false));
    assertThrows(IllegalStateException.class, () -> cipher.decrypt("enc:v9:a:bad"));
  }
  @Test void rotationReadsPreviousKeysAndWritesOnlyActiveKey() {
    var old = encryption("old", "old=" + key(1), false);
    var current = encryption("new", "old=" + key(1) + ",new=" + key(2), true);
    assertEquals("data", current.decrypt(old.encrypt("data")));
    assertTrue(current.encrypt("data").startsWith("enc:v1:new:"));
    assertEquals("legacy", current.decrypt("legacy"));
  }
  @Test void representativeBatchPreservesValuesAndReportsLocalOverhead() {
    var cipher = encryption("a", "a=" + key(1), false);
    String value = "Representative private field ".repeat(8);
    for (int i = 0; i < 1000; i++) cipher.decrypt(cipher.encrypt(value));
    long start = System.nanoTime();
    for (int i = 0; i < 10000; i++) assertEquals(value, cipher.decrypt(cipher.encrypt(value)));
    System.out.printf("Field encryption local sample: 10000 encrypt/decrypt pairs in %.1f ms%n", (System.nanoTime() - start) / 1_000_000.0);
  }
}

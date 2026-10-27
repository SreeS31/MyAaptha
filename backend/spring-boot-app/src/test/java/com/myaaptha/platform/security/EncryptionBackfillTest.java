package com.myaaptha.platform.security;

import com.myaaptha.release.EncryptSensitiveFields;
import static org.junit.jupiter.api.Assertions.*;
import java.sql.DriverManager;
import org.junit.jupiter.api.Test;

class EncryptionBackfillTest {
  @Test void backfillIsBoundedRestartableAndSupportsRotation() throws Exception {
    try (var connection = DriverManager.getConnection("jdbc:h2:mem:backfill;MODE=PostgreSQL")) {
      try (var sql = connection.createStatement()) {
        for (var table : EncryptSensitiveFields.FIELDS.entrySet()) {
          String ids = table.getKey().equals("person_records") ? "owner_user_id BIGINT,person_user_id BIGINT" : "id BIGINT";
          sql.execute("CREATE TABLE " + table.getKey() + " (" + ids + "," + String.join(",", table.getValue().stream().map(field -> field + " TEXT").toList()) + ")");
        }
        for (int i = 0; i < 260; i++) sql.execute("INSERT INTO relationships (id,contact_name) VALUES (" + i + ",'private')");
      }
      var first = FieldEncryptionTest.encryption("old", "old=" + FieldEncryptionTest.key(1), true);
      assertEquals(260, EncryptSensitiveFields.migrate(connection, first, "old"));
      assertEquals(0, EncryptSensitiveFields.migrate(connection, first, "old"));
      var rotated = FieldEncryptionTest.encryption("new", "old=" + FieldEncryptionTest.key(1) + ",new=" + FieldEncryptionTest.key(2), true);
      assertEquals(260, EncryptSensitiveFields.migrate(connection, rotated, "new"));
      try (var sql = connection.createStatement(); var rows = sql.executeQuery("SELECT contact_name FROM relationships")) {
        while (rows.next()) { assertTrue(rows.getString(1).startsWith("enc:v1:new:")); assertEquals("private", rotated.decrypt(rows.getString(1))); }
      }
    }
  }
}

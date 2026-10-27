package com.myaaptha.release;

import com.myaaptha.platform.security.FieldEncryption;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.StandardEnvironment;

/** Offline, bounded, restartable backfill/key rotation. Run after V56, before application startup. */
public final class EncryptSensitiveFields {
  public static final Map<String, List<String>> FIELDS = Map.of(
      "relationships", List.of("contact_name", "contact_phone", "contact_email", "milestone_date", "related_birth_date", "related_death_date"),
      "person_records", List.of("nickname", "contact_phone", "contact_email", "address", "city", "country", "occupation", "date_of_birth", "marriage_date", "date_of_death", "important_dates", "notes"),
      "health_reports", List.of("report_name", "laboratory", "notes"),
      "health_measurements", List.of("metric_name", "unit", "suggestion", "measured_value", "reference_min", "reference_max"),
      "financial_transactions", List.of("merchant", "description", "amount"),
      "users", List.of("managed_notes", "managed_date_of_birth", "managed_date_of_death"));

  public static void main(String[] args) throws Exception {
    String keyId = System.getenv().getOrDefault("MYAAPTHA_FIELD_ACTIVE_KEY_ID", "primary");
    var environment = new StandardEnvironment();
    environment.getPropertySources().addFirst(new MapPropertySource("backfill", Map.of(
        "security.fields.enabled", true, "security.fields.allow-legacy-reads", true,
        "security.fields.active-key-id", keyId,
        "security.fields.keys", secret("MYAAPTHA_FIELD_ENCRYPTION_KEYS", "field_encryption_keys"))));
    var encryption = new FieldEncryption(environment);
    String host = System.getenv("POSTGRES_HOST");
    if (host == null || !host.matches("[A-Za-z0-9.-]+")) throw new IllegalStateException("Set POSTGRES_HOST");
    String url = "jdbc:postgresql://" + host + ":" + System.getenv().getOrDefault("POSTGRES_PORT", "5432")
        + "/" + System.getenv().getOrDefault("POSTGRES_DB", "myaaptha") + "?sslmode=verify-full";
    try (Connection connection = DriverManager.getConnection(url, System.getenv().getOrDefault("POSTGRES_USER", "myaaptha"), secret("POSTGRES_PASSWORD", "postgres_password"))) {
      long count = migrate(connection, encryption, keyId);
      System.out.println("Sensitive-field migration completed. Updated rows: " + count);
    }
  }

  public static long migrate(Connection connection, FieldEncryption encryption, String keyId) throws Exception {
    if (!keyId.matches("[A-Za-z0-9_-]{1,32}")) throw new IllegalArgumentException("Invalid key ID");
    long updated = 0;
    boolean autoCommit = connection.getAutoCommit();
    connection.setAutoCommit(false);
    try {
      for (var table : FIELDS.entrySet()) {
        List<String> ids = table.getKey().equals("person_records") ? List.of("owner_user_id", "person_user_id") : List.of("id");
        String pending = String.join(" OR ", table.getValue().stream().map(column -> "(" + column + " IS NOT NULL AND " + "LEFT(" + column + "," + ("enc:v1:" + keyId + ":").length() + ") <> 'enc:v1:" + keyId + ":')").toList());
        String select = "SELECT " + String.join(",", ids) + "," + String.join(",", table.getValue()) + " FROM " + table.getKey() + " WHERE " + pending + " LIMIT 250 FOR UPDATE";
        String update = "UPDATE " + table.getKey() + " SET " + String.join(",", table.getValue().stream().map(column -> column + "=?").toList()) + " WHERE " + String.join(" AND ", ids.stream().map(id -> id + "=?").toList());
        while (true) {
          var rows = new ArrayList<Map<String, Object>>();
          try (var statement = connection.createStatement(); var result = statement.executeQuery(select)) {
            while (result.next()) {
              var row = new LinkedHashMap<String, Object>();
              for (String id : ids) row.put(id, result.getLong(id));
              for (String column : table.getValue()) row.put(column, result.getString(column));
              rows.add(row);
            }
          }
          if (rows.isEmpty()) { connection.commit(); break; }
          try (var statement = connection.prepareStatement(update)) {
            for (var row : rows) {
              int index = 1;
              for (String column : table.getValue()) statement.setString(index++, encryption.encrypt(encryption.decrypt((String) row.get(column))));
              for (String id : ids) statement.setObject(index++, row.get(id));
              statement.addBatch();
            }
            statement.executeBatch();
          }
          connection.commit(); updated += rows.size();
        }
      }
      return updated;
    } catch (Exception error) { connection.rollback(); throw error; }
    finally { connection.setAutoCommit(autoCommit); }
  }

  private static String secret(String variable, String file) throws Exception {
    String value = System.getenv(variable);
    return value == null || value.isBlank() ? Files.readString(Path.of("/run/secrets", file)).trim() : value;
  }
}

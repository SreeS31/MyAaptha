package com.myaaptha.release;

import java.nio.file.Files;
import java.nio.file.Path;
import org.flywaydb.core.Flyway;

/** One-off release task; does not start the HTTP server, schedulers, or demo seeder. */
public final class DatabaseMigration {
  public static void main(String[] args) throws Exception {
    String password = System.getenv("POSTGRES_PASSWORD");
    if (password == null || password.isBlank()) password = Files.readString(Path.of("/run/secrets/postgres_password")).trim();
    String url = "jdbc:postgresql://" + required("POSTGRES_HOST") + ":" + value("POSTGRES_PORT", "5432")
        + "/" + value("POSTGRES_DB", "myaaptha") + "?sslmode=" + value("POSTGRES_SSLMODE", "verify-full");
    Flyway.configure().dataSource(url, value("POSTGRES_USER", "myaaptha"), password)
        .locations("classpath:db/migration/common").cleanDisabled(true).validateOnMigrate(true)
        .load().migrate();
  }
  private static String value(String key, String fallback) {
    String result = System.getenv(key); return result == null || result.isBlank() ? fallback : result;
  }
  private static String required(String key) {
    String result = value(key, "");
    if (result.isBlank()) throw new IllegalStateException("Missing migration configuration: " + key);
    return result;
  }
}

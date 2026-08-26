package com.myaaptha.config;

import java.sql.Connection;
import java.sql.Statement;

import javax.sql.DataSource;

import org.springframework.boot.CommandLineRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.stereotype.Component;

@Component
public class DatabaseViewInitializer implements CommandLineRunner {
  private final DataSource dataSource;

  public DatabaseViewInitializer(DataSource dataSource) {
    this.dataSource = dataSource;
  }

  @Override
  public void run(String... args) throws Exception {
    ResourceDatabasePopulator populator = new ResourceDatabasePopulator(false, false, "UTF-8", new ClassPathResource("db/views.sql"));
    try (Connection connection = dataSource.getConnection(); Statement statement = connection.createStatement()) {
      statement.execute("CREATE SCHEMA IF NOT EXISTS PUBLIC");
    }
    populator.populate(dataSource.getConnection());
  }
}

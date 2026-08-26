package com.myaaptha.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
  private final String[] allowedOrigins;

  public CorsConfig(@Value("${myaaptha.cors.allowed-origins:http://localhost:3000,http://127.0.0.1:3000,http://localhost:3002,http://127.0.0.1:3002,http://localhost:8088,http://127.0.0.1:8088}") String origins) {
    this.allowedOrigins = java.util.Arrays.stream(origins.split(","))
        .map(String::trim).filter(value -> !value.isBlank()).toArray(String[]::new);
  }

  @Override
  public void addCorsMappings(CorsRegistry registry) {
    registry.addMapping("/api/**")
        .allowedOrigins(allowedOrigins)
        .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
        .allowedHeaders("*")
        .allowCredentials(true);
  }
}

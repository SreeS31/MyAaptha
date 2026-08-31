package com.myaaptha.config;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationFeature;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebValidationConfiguration implements WebMvcConfigurer {
  private final ApiValidationAdvice validationAdvice;

  public WebValidationConfiguration(ApiValidationAdvice validationAdvice) {
    this.validationAdvice = validationAdvice;
  }

  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    registry.addInterceptor(validationAdvice).addPathPatterns("/api/**");
  }

  @Bean
  Jackson2ObjectMapperBuilderCustomizer strictRequestJson() {
    return builder -> builder.featuresToEnable(
        DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES,
        JsonParser.Feature.STRICT_DUPLICATE_DETECTION);
  }
}

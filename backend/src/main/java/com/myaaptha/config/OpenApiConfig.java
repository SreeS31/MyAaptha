package com.myaaptha.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI myAapthaOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("MyAaptha API")
                        .description("Intelligent Relationship Network Management Platform")
                        .version("1.0.0")
                        .contact(new Contact().name("MyAaptha Team").email("support@myaaptha.io")))
                .addSecurityItem(new SecurityRequirement().addList("Bearer Auth"))
                .schemaRequirement("Bearer Auth", new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT"));
    }
}

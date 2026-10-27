package com.myaaptha.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "myaaptha.jwt")
@Getter
@Setter
public class JwtProperties {
    private String secret;
    private long accessTokenExpirationMs = 900_000;
    private long refreshTokenExpirationMs = 604_800_000;
}

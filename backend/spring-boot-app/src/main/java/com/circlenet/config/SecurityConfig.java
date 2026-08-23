package com.circlenet.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.config.Customizer;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.security.web.header.writers.StaticHeadersWriter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {
  private final JwtAuthenticationFilter jwtAuthenticationFilter;
  private final RateLimitFilter rateLimitFilter;

  public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter, RateLimitFilter rateLimitFilter) {
    this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    this.rateLimitFilter = rateLimitFilter;
  }

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http
      .csrf(csrf -> csrf.disable())
      .cors(Customizer.withDefaults())
      .headers(headers -> headers
        .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"))
        .referrerPolicy(referrer -> referrer.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER))
        .addHeaderWriter(new StaticHeadersWriter("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=()"))
        .httpStrictTransportSecurity(hsts -> hsts.includeSubDomains(true).preload(true).maxAgeInSeconds(63072000)))
      .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
      .authorizeHttpRequests(auth -> auth
        .requestMatchers("/actuator/health").permitAll()
        .requestMatchers("/api/auth/health", "/api/auth/login", "/api/auth/refresh", "/api/auth/logout", "/api/auth/revoke").permitAll()
        .requestMatchers(HttpMethod.GET, "/api/contact-organizer/oauth/callback/**").permitAll()
        .requestMatchers(HttpMethod.POST, "/api/users").permitAll()
        .requestMatchers(HttpMethod.GET, "/api/profile/media/**").permitAll()
        .requestMatchers(HttpMethod.GET, "/api/notifications/unsubscribe/**").permitAll()
        .requestMatchers(HttpMethod.PUT, "/api/profile/me").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/network/relationships/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/network/circles/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/network/messages/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/notifications/preferences").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/people/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/network/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/social/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/privacy/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/profile/me/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/people/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/**").hasRole("ADMIN")
        .requestMatchers(HttpMethod.DELETE, "/api/**").hasRole("ADMIN")
        .requestMatchers("/api/**").authenticated()
        .anyRequest().authenticated())
      .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
    http.addFilterBefore(rateLimitFilter, JwtAuthenticationFilter.class);

    return http.build();
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
  }
}

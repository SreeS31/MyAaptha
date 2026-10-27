package com.myaaptha.config;

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
  private final WebCookieAuthenticationFilter webCookies;

  public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter, RateLimitFilter rateLimitFilter, WebCookieAuthenticationFilter webCookies) {
    this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    this.rateLimitFilter = rateLimitFilter;this.webCookies=webCookies;
  }

  @Bean
  org.springframework.boot.web.servlet.FilterRegistrationBean<RateLimitFilter> rateLimitRegistration() {
    var registration=new org.springframework.boot.web.servlet.FilterRegistrationBean<>(rateLimitFilter);
    registration.setEnabled(false);return registration;
  }
  @Bean
  org.springframework.boot.web.servlet.FilterRegistrationBean<JwtAuthenticationFilter> jwtRegistration() {
    var registration=new org.springframework.boot.web.servlet.FilterRegistrationBean<>(jwtAuthenticationFilter);
    registration.setEnabled(false);return registration;
  }

  @Bean org.springframework.boot.web.servlet.FilterRegistrationBean<WebCookieAuthenticationFilter> cookieRegistration(){var registration=new org.springframework.boot.web.servlet.FilterRegistrationBean<>(webCookies);registration.setEnabled(false);return registration;}
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
        .requestMatchers("/actuator/health", "/actuator/health/liveness", "/actuator/health/readiness").permitAll()
        .requestMatchers(HttpMethod.GET,"/actuator/prometheus").hasAnyRole("ADMIN","METRICS")
        .requestMatchers("/actuator","/actuator/**").hasRole("ADMIN")
        .requestMatchers("/api/auth/security-policy","/api/auth/phone/start","/api/auth/reset-password","/api/web-auth/login","/api/web-auth/refresh","/api/web-auth/logout","/api/web-auth/revoke","/api/auth/health", "/api/auth/login", "/api/auth/refresh", "/api/auth/logout", "/api/auth/revoke").permitAll()
        .requestMatchers(HttpMethod.GET, "/api/contact-organizer/oauth/callback/**").permitAll()
        .requestMatchers(HttpMethod.POST, "/api/users").permitAll()
        .requestMatchers("/api/admin/upload-levels", "/api/admin/upload-levels/**").hasRole("ADMIN")
          .requestMatchers("/api/admin/security/**").hasRole("ADMIN")
        .requestMatchers("/api/ai/help/admin/**").hasRole("ADMIN")
        .requestMatchers(HttpMethod.DELETE, "/api/ai/help/history").authenticated()
        // These are platform-wide administration APIs, not the owner-scoped
        // /api/network and /api/people/{id}/profile APIs used by members.
        .requestMatchers("/api/users", "/api/users/*", "/api/circles", "/api/circles/**",
            "/api/relationships", "/api/relationships/**", "/api/permissions", "/api/permissions/**",
            "/api/people", "/api/people/*", "/api/dashboard/summary").hasRole("ADMIN")
        .requestMatchers(HttpMethod.GET, "/api/profile/media/**").permitAll()
        .requestMatchers(HttpMethod.GET, "/api/notifications/unsubscribe/**").permitAll()
        .requestMatchers(HttpMethod.PUT, "/api/profile/me", "/api/timeline/events/*").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/timeline/events/*").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/settings/me").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/ai/preferences", "/api/ai/approvals/*/decision").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/social/posts/*", "/api/social/posts/*/reaction", "/api/social/posts/*/pin").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/network/relationships/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/network/circles/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/network/messages/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/network/chats/circles/*/*/flags").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/address-book/**").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/notifications/preferences").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/people/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/network/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/address-book", "/api/address-book/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/social/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/privacy/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/profile/me/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/people/**").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/finance/transactions/*").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/finance/renewals/*", "/api/finance/renewals/*/state").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/finance/renewals/*", "/api/finance/renewals/*/attachment").authenticated()
        .requestMatchers(HttpMethod.DELETE, "/api/health/reports/*", "/api/notifications/devices",
            "/api/trust/people/*", "/api/trust/role-models/*/follow").authenticated()
        .requestMatchers(HttpMethod.PUT, "/api/**").hasRole("ADMIN")
        .requestMatchers(HttpMethod.DELETE, "/api/**").hasRole("ADMIN")
        .requestMatchers("/api/**").authenticated()
        .anyRequest().authenticated())
      .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
    http.addFilterBefore(webCookies,JwtAuthenticationFilter.class);
    http.addFilterAfter(rateLimitFilter, JwtAuthenticationFilter.class);

    return http.build();
  }

  @Bean
  public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
  }
}

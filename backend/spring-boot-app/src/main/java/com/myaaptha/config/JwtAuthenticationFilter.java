package com.myaaptha.config;

import java.io.IOException;
import java.util.Set;

import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.myaaptha.domain.auth.JwtTokenService;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
  private static final Set<String> PUBLIC_AUTH_PATHS = Set.of(
      "/api/auth/security-policy","/api/auth/phone/start","/api/auth/reset-password","/api/web-auth/login","/api/web-auth/refresh","/api/web-auth/logout","/api/web-auth/revoke",
      "/api/auth/health",
      "/api/auth/login",
      "/api/auth/refresh",
      "/api/auth/logout",
      "/api/auth/revoke");

  private final JwtTokenService jwtTokenService;
  private final com.myaaptha.domain.auth.AuthTokenRepository sessions;
  private final MetricsScrapeCredential metrics;

  public JwtAuthenticationFilter(JwtTokenService jwtTokenService,com.myaaptha.domain.auth.AuthTokenRepository sessions,MetricsScrapeCredential metrics) {
    this.jwtTokenService = jwtTokenService;this.sessions=sessions;this.metrics=metrics;
  }

  @Override
  protected void doFilterInternal(
      HttpServletRequest request,
      HttpServletResponse response,
      FilterChain filterChain) throws ServletException, IOException {

    if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
      filterChain.doFilter(request, response);
      return;
    }

    String path = request.getRequestURI();
    boolean operational=(path.equals("/actuator")||path.startsWith("/actuator/"))
        && !Set.of("/actuator/health","/actuator/health/liveness","/actuator/health/readiness").contains(path);
    if (!path.startsWith("/api/") && !operational) {
      filterChain.doFilter(request, response);
      return;
    }

    if (isPublicEndpoint(request, path)) {
      filterChain.doFilter(request, response);
      return;
    }

    String authorizationHeader = request.getHeader(HttpHeaders.AUTHORIZATION);
    if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
      response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
      return;
    }

    String token = authorizationHeader.substring("Bearer ".length()).trim();
    try {
      if(metrics.accepts(request.getMethod(),path,token)) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
            "metrics-scraper",null,AuthorityUtils.createAuthorityList("ROLE_METRICS")));
        filterChain.doFilter(request,response);return;
      }
      Claims claims = jwtTokenService.parseAndValidate(token, "access");
      String role = claims.get("role", String.class);
      String sid=claims.get("sid",String.class);
      if(sid==null||!sessions.activeSession(sid,Long.valueOf(claims.getSubject()),role,java.time.Instant.now())){response.setStatus(401);return;}
      UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
          claims.getSubject(),
          null,
          role == null ? AuthorityUtils.NO_AUTHORITIES : AuthorityUtils.createAuthorityList("ROLE_" + role));
      SecurityContextHolder.getContext().setAuthentication(authentication);
      filterChain.doFilter(request, response);
    } catch (IllegalArgumentException ex) {
      response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
    } finally {
      SecurityContextHolder.clearContext();
    }
  }

  private boolean isPublicEndpoint(HttpServletRequest request, String path) {
    if ("/actuator/health".equals(path)) {
      return true;
    }

    if (PUBLIC_AUTH_PATHS.contains(path)) {
      return true;
    }

    if ("GET".equalsIgnoreCase(request.getMethod()) && path.startsWith("/api/profile/media/")) {
      return true;
    }

    if ("GET".equalsIgnoreCase(request.getMethod())
        && path.startsWith("/api/contact-organizer/oauth/callback/")) {
      return true;
    }

    if ("GET".equalsIgnoreCase(request.getMethod())
        && path.startsWith("/api/notifications/unsubscribe/")) {
      return true;
    }

    return "POST".equalsIgnoreCase(request.getMethod()) && "/api/users".equals(path);
  }
}

package com.myaaptha.domain.auth;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestHeader;

import com.myaaptha.domain.auth.dto.AuthLoginRequest;
import com.myaaptha.domain.auth.dto.AuthSessionProfileResponse;
import com.myaaptha.domain.auth.dto.AuthRefreshRequest;
import com.myaaptha.domain.auth.dto.AuthTokenResponse;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
  private final AuthService authService;

  public AuthController(AuthService authService) {
    this.authService = authService;
  }

  @GetMapping("/health")
  public String health() {
    return "auth-service-ready";
  }

  @GetMapping("/me")
  public ResponseEntity<AuthSessionProfileResponse> me(@RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authorizationHeader) {
    if (authorizationHeader == null || !authorizationHeader.startsWith("Bearer ")) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }

    try {
      String accessToken = authorizationHeader.substring("Bearer ".length()).trim();
      return ResponseEntity.ok(authService.getSessionProfile(accessToken));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
  }

  @PostMapping("/login")
  public ResponseEntity<AuthTokenResponse> login(@Valid @RequestBody AuthLoginRequest request) {
    try {
      return ResponseEntity.ok(authService.login(request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
  }

  @PostMapping("/refresh")
  public ResponseEntity<AuthTokenResponse> refresh(@Valid @RequestBody AuthRefreshRequest request) {
    try {
      return ResponseEntity.ok(authService.refresh(request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
  }

  @PostMapping("/logout")
  public ResponseEntity<Void> logout(@Valid @RequestBody AuthRefreshRequest request) {
    try {
      authService.logout(request);
      return ResponseEntity.noContent().build();
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
  }

  @PostMapping("/revoke")
  public ResponseEntity<Void> revoke(@Valid @RequestBody AuthRefreshRequest request) {
    try {
      authService.revoke(request);
      return ResponseEntity.noContent().build();
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }
  }
}

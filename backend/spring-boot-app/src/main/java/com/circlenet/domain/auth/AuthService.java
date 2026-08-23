package com.circlenet.domain.auth;

import java.time.Instant;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.circlenet.domain.auth.dto.AuthLoginRequest;
import com.circlenet.domain.auth.dto.AuthSessionProfileResponse;
import com.circlenet.domain.auth.dto.AuthRefreshRequest;
import com.circlenet.domain.auth.dto.AuthTokenResponse;
import com.circlenet.domain.auth.model.AuthTokenEntity;
import com.circlenet.domain.user.UserRepository;
import com.circlenet.domain.user.model.UserEntity;

import io.jsonwebtoken.Claims;

@Service
@Transactional
public class AuthService {
  private final AuthTokenRepository authTokenRepository;
  private final UserRepository userRepository;
  private final JwtTokenService jwtTokenService;
  private final PasswordEncoder passwordEncoder;

  public AuthService(
      AuthTokenRepository authTokenRepository,
      UserRepository userRepository,
      JwtTokenService jwtTokenService,
      PasswordEncoder passwordEncoder) {
    this.authTokenRepository = authTokenRepository;
    this.userRepository = userRepository;
    this.jwtTokenService = jwtTokenService;
    this.passwordEncoder = passwordEncoder;
  }

  public List<AuthTokenEntity> listTokens() {
    return authTokenRepository.findAll();
  }

  public AuthTokenEntity createToken(AuthTokenEntity token) {
    return authTokenRepository.save(token);
  }

  public void deleteToken(Long id) {
    authTokenRepository.deleteById(id);
  }

  public AuthTokenResponse login(AuthLoginRequest request) {
    String identifier = request.getIdentifier();
    if (identifier == null || identifier.isBlank()) {
      identifier = request.getEmail();
    }
    if (identifier == null || identifier.isBlank() || request.getPassword() == null || request.getPassword().isBlank()) {
      throw new IllegalArgumentException("Invalid username, email, phone number, or password");
    }

    String normalizedIdentifier = identifier.trim();
    UserEntity user = userRepository.findByEmail(normalizedIdentifier.toLowerCase())
      .or(() -> userRepository.findByPhoneNumber(normalizePhoneNumber(normalizedIdentifier)))
      .or(() -> userRepository.findByUsernameIgnoreCase(normalizedIdentifier))
      .orElseThrow(() -> new IllegalArgumentException("Invalid username, email, phone number, or password"));

    if (!"ACTIVE".equals(user.getAccountStatus())) {
      throw new IllegalArgumentException("This profile cannot sign in");
    }

    if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
      throw new IllegalArgumentException("Invalid username, email, phone number, or password");
    }

    return issueNewSession(user, null);
  }

  public AuthTokenResponse refresh(AuthRefreshRequest request) {
    Claims claims = jwtTokenService.parseAndValidate(request.getRefreshToken(), "refresh");
    Long userId = Long.parseLong(claims.getSubject());

    AuthTokenEntity storedToken = authTokenRepository.findByToken(tokenFingerprint(request.getRefreshToken()))
      .orElseThrow(() -> new IllegalArgumentException("Refresh token not recognized"));

    if (storedToken.getExpiresAt().isBefore(Instant.now())) {
      authTokenRepository.deleteByToken(tokenFingerprint(request.getRefreshToken()));
      throw new IllegalArgumentException("Refresh token expired");
    }

    if (!"refresh".equals(storedToken.getTokenType()) || !userId.equals(storedToken.getUserId())) {
      throw new IllegalArgumentException("Invalid refresh token context");
    }

    UserEntity user = userRepository.findById(userId)
      .orElseThrow(() -> new IllegalArgumentException("User not found"));

    return issueNewSession(user, storedToken.getToken());
  }

  public void logout(AuthRefreshRequest request) {
    revoke(request);
  }

  public void revoke(AuthRefreshRequest request) {
    Claims claims = jwtTokenService.parseAndValidate(request.getRefreshToken(), "refresh");
    Long userId = Long.parseLong(claims.getSubject());

    AuthTokenEntity storedToken = authTokenRepository.findByToken(tokenFingerprint(request.getRefreshToken()))
      .orElseThrow(() -> new IllegalArgumentException("Refresh token not recognized"));

    if (!"refresh".equals(storedToken.getTokenType()) || !userId.equals(storedToken.getUserId())) {
      throw new IllegalArgumentException("Invalid refresh token context");
    }

    authTokenRepository.deleteByToken(tokenFingerprint(request.getRefreshToken()));
  }

  public AuthSessionProfileResponse getSessionProfile(String accessToken) {
    Claims claims = jwtTokenService.parseAndValidate(accessToken, "access");
    Long userId = Long.parseLong(claims.getSubject());

    UserEntity user = userRepository.findById(userId)
      .orElseThrow(() -> new IllegalArgumentException("User not found"));

    AuthSessionProfileResponse response = new AuthSessionProfileResponse();
    response.setId(user.getId());
    response.setUsername(user.getUsername());
    response.setEmail(user.getEmail());
    response.setRole(user.getRole());
    response.setPhoneNumber(user.getPhoneNumber());
    return response;
  }

  private AuthTokenResponse issueNewSession(UserEntity user, String oldRefreshToken) {
    String accessToken = jwtTokenService.createAccessToken(user);
    String refreshToken = jwtTokenService.createRefreshToken(user);

    if (oldRefreshToken != null) {
      authTokenRepository.deleteByToken(tokenFingerprint(oldRefreshToken));
    }
    authTokenRepository.deleteByUserIdAndTokenType(user.getId(), "refresh");

    AuthTokenEntity refreshTokenEntity = new AuthTokenEntity();
    refreshTokenEntity.setUserId(user.getId());
    refreshTokenEntity.setTokenType("refresh");
    // Store only a one-way fingerprint. A database leak must not expose reusable sessions.
    refreshTokenEntity.setToken(tokenFingerprint(refreshToken));
    refreshTokenEntity.setExpiresAt(jwtTokenService.getRefreshTokenExpiryInstant());
    authTokenRepository.save(refreshTokenEntity);

    AuthTokenResponse response = new AuthTokenResponse();
    response.setTokenType("Bearer");
    response.setAccessToken(accessToken);
    response.setRefreshToken(refreshToken);
    response.setExpiresIn(jwtTokenService.getAccessTokenExpirySeconds());
    return response;
  }

  private String normalizePhoneNumber(String value) {
    String compact = value.replaceAll("[\\s()-]", "");
    if (compact.matches("[0-9]{10}")) {
      return "+91" + compact;
    }
    return compact;
  }

  private String tokenFingerprint(String token) {
    if (token == null || token.isBlank()) {
      throw new IllegalArgumentException("Refresh token is required");
    }
    try {
      return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
          .digest(token.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException("Unable to secure refresh token", exception);
    }
  }
}

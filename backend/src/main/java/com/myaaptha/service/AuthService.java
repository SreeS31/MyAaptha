package com.myaaptha.service;

import com.myaaptha.domain.user.User;
import com.myaaptha.dto.auth.AuthResponse;
import com.myaaptha.dto.auth.LoginRequest;
import com.myaaptha.dto.auth.RegisterRequest;
import com.myaaptha.exception.BusinessException;
import com.myaaptha.repository.UserRepository;
import com.myaaptha.security.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (request.getEmail() != null && userRepository.existsByEmail(request.getEmail())) {
            throw new BusinessException("EMAIL_EXISTS", "Email already registered");
        }
        if (request.getMobile() != null && userRepository.existsByMobile(request.getMobile())) {
            throw new BusinessException("MOBILE_EXISTS", "Mobile already registered");
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .mobile(request.getMobile())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .build();

        user = userRepository.save(user);
        return buildAuthResponse(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .or(() -> userRepository.findByMobile(request.getMobile()))
                .orElseThrow(() -> new BusinessException("INVALID_CREDENTIALS", "Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new BusinessException("INVALID_CREDENTIALS", "Invalid credentials");
        }

        user.setLastLoginAt(Instant.now());
        userRepository.save(user);
        return buildAuthResponse(user);
    }

    private AuthResponse buildAuthResponse(User user) {
        String token = jwtTokenProvider.generateAccessToken(user.getId(), user.getEmail());
        return AuthResponse.builder()
                .userId(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .accessToken(token)
                .tokenType("Bearer")
                .expiresIn(900)
                .build();
    }
}

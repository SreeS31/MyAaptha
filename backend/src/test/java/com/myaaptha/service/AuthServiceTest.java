package com.myaaptha.service;

import com.myaaptha.dto.auth.LoginRequest;
import com.myaaptha.dto.auth.RegisterRequest;
import com.myaaptha.exception.BusinessException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock private com.myaaptha.repository.UserRepository userRepository;
    @Mock private PasswordEncoder passwordEncoder;
    @Mock private com.myaaptha.security.JwtTokenProvider jwtTokenProvider;

    @InjectMocks
    private AuthService authService;

    @Test
    void register_throwsWhenEmailExists() {
        RegisterRequest req = new RegisterRequest();
        req.setFullName("Test User");
        req.setEmail("test@example.com");
        req.setPassword("password123");

        when(userRepository.existsByEmail("test@example.com")).thenReturn(true);

        assertThrows(BusinessException.class, () -> authService.register(req));
    }

    @Test
    void login_throwsOnInvalidCredentials() {
        LoginRequest req = new LoginRequest();
        req.setEmail("unknown@example.com");
        req.setPassword("wrong");

        when(userRepository.findByEmail("unknown@example.com")).thenReturn(java.util.Optional.empty());

        assertThrows(BusinessException.class, () -> authService.login(req));
    }
}

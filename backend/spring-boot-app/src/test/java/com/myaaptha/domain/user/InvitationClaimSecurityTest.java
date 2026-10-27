package com.myaaptha.domain.user;

import com.myaaptha.domain.user.dto.CreateUserRequest;
import com.myaaptha.domain.user.model.UserEntity;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class InvitationClaimSecurityTest {
  @Test void unverifiedRegistrationCannotTakeOverAnInvitedIdentity() {
    UserRepository repository = mock(UserRepository.class);
    PasswordEncoder encoder = mock(PasswordEncoder.class);
    UserService service = new UserService(repository, encoder, mock(com.myaaptha.domain.auth.PhoneVerificationService.class));
    UserEntity invited = new UserEntity();
    invited.setAccountStatus("INVITED");
    when(repository.findByPhoneNumber("+919876543210")).thenReturn(Optional.of(invited));
    CreateUserRequest request = new CreateUserRequest();
    request.setUsername("attacker"); request.setPhoneNumber("+919876543210"); request.setPassword("SecurePassword123!");
    ResponseStatusException error = assertThrows(ResponseStatusException.class, () -> service.createUser(request));
    assertEquals(409, error.getStatusCode().value());
    assertEquals("INVITED", invited.getAccountStatus());
    verify(repository, never()).save(any());
  }
}

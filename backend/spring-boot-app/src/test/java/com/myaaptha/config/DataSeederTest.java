package com.myaaptha.config;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.permission.PermissionRepository;
import com.myaaptha.domain.person.PersonRepository;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.user.UserRepository;

@ExtendWith(MockitoExtension.class)
class DataSeederTest {
  @Mock
  private UserRepository userRepository;

  @Mock
  private PersonRepository personRepository;

  @Mock
  private CircleRepository circleRepository;

  @Mock
  private RelationshipRepository relationshipRepository;

  @Mock
  private PermissionRepository permissionRepository;

  @Mock
  private PasswordEncoder passwordEncoder;

  @InjectMocks
  private DataSeeder dataSeeder;

  @Test
  void shouldSeedRepositoriesWhenEmpty() {
    when(userRepository.count()).thenReturn(0L);
    when(personRepository.count()).thenReturn(0L);
    when(circleRepository.count()).thenReturn(0L);
    when(relationshipRepository.count()).thenReturn(0L);
    when(permissionRepository.count()).thenReturn(0L);
    when(passwordEncoder.encode(any())).thenReturn("hashed-password");

    dataSeeder.run();

    verify(userRepository).save(any());
    verify(personRepository).save(any());
    verify(circleRepository).save(any());
    verify(relationshipRepository).save(any());
    verify(permissionRepository).save(any());
  }
}

package com.myaaptha.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.myaaptha.domain.circle.CircleRepository;
import com.myaaptha.domain.circle.model.CircleEntity;
import com.myaaptha.domain.permission.PermissionRepository;
import com.myaaptha.domain.permission.model.PermissionEntity;
import com.myaaptha.domain.person.PersonRepository;
import com.myaaptha.domain.person.model.PersonEntity;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;

@Component
@Profile("!prod")
public class DataSeeder implements CommandLineRunner {
  private final UserRepository userRepository;
  private final PersonRepository personRepository;
  private final CircleRepository circleRepository;
  private final RelationshipRepository relationshipRepository;
  private final PermissionRepository permissionRepository;
  private final PasswordEncoder passwordEncoder;

  public DataSeeder(
      UserRepository userRepository,
      PersonRepository personRepository,
      CircleRepository circleRepository,
      RelationshipRepository relationshipRepository,
      PermissionRepository permissionRepository,
      PasswordEncoder passwordEncoder) {
    this.userRepository = userRepository;
    this.personRepository = personRepository;
    this.circleRepository = circleRepository;
    this.relationshipRepository = relationshipRepository;
    this.permissionRepository = permissionRepository;
    this.passwordEncoder = passwordEncoder;
  }

  @Override
  public void run(String... args) {
    migrateLegacyPasswords();

    if (userRepository.count() == 0) {
      UserEntity user = new UserEntity();
      user.setUsername("admin");
      user.setEmail("admin@myaaptha.ai");
      user.setPhoneNumber("+10000000000");
      user.setRole("ADMIN");
      user.setPasswordHash(passwordEncoder.encode("admin123"));
      userRepository.save(user);
    }

    if (personRepository.count() == 0) {
      PersonEntity person = new PersonEntity();
      person.setFullName("Ava Patel");
      person.setEmail("ava@myaaptha.ai");
      personRepository.save(person);
    }

    if (circleRepository.count() == 0) {
      CircleEntity circle = new CircleEntity();
      circle.setName("Engineering");
      circle.setDescription("Core platform collaboration circle");
      circleRepository.save(circle);
    }

    if (relationshipRepository.count() == 0) {
      RelationshipEntity relationship = new RelationshipEntity();
      relationship.setType("friend");
      relationshipRepository.save(relationship);
    }

    if (permissionRepository.count() == 0) {
      PermissionEntity permission = new PermissionEntity();
      permission.setName("admin");
      permission.setDescription("Full platform access");
      permissionRepository.save(permission);
    }
  }

  private void migrateLegacyPasswords() {
    userRepository.findAll().forEach((user) -> {
      if (!isBcryptHash(user.getPasswordHash())) {
        user.setPasswordHash(passwordEncoder.encode(user.getPasswordHash()));
        userRepository.save(user);
      }
    });
  }

  private boolean isBcryptHash(String passwordHash) {
    return passwordHash != null
      && (passwordHash.startsWith("$2a$") || passwordHash.startsWith("$2b$") || passwordHash.startsWith("$2y$"));
  }
}

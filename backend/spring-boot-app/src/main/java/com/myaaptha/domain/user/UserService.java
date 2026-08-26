package com.myaaptha.domain.user;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import com.myaaptha.domain.user.dto.CreateUserRequest;
import com.myaaptha.domain.user.dto.UserDto;
import com.myaaptha.domain.user.model.UserEntity;

@Service
public class UserService {
  private final UserRepository userRepository;
  private final PasswordEncoder passwordEncoder;

  public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
    this.userRepository = userRepository;
    this.passwordEncoder = passwordEncoder;
  }

  public List<UserDto> listUsers() {
    return userRepository.findAll().stream().map(this::toDto).collect(Collectors.toList());
  }

  public UserDto getUser(Long id) {
    return userRepository.findById(id).map(this::toDto).orElseThrow(() -> new IllegalArgumentException("User not found"));
  }

  public UserDto createUser(CreateUserRequest request) {
    String username = requireValue(request.getUsername(), "Username");
    String email = optionalEmail(request.getEmail());
    String phoneNumber = normalizePhoneNumber(request.getPhoneNumber());
    String password = validatePassword(request.getPassword());

    if (userRepository.existsByUsername(username)) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "Username is already in use");
    }
    UserEntity invitedUser = userRepository.findByPhoneNumber(phoneNumber)
        .filter(user -> "INVITED".equals(user.getAccountStatus())).orElse(null);
    if (email != null && userRepository.findByEmail(email)
        .filter(user -> invitedUser == null || !user.getId().equals(invitedUser.getId())).isPresent()) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "Email is already in use");
    }
    if (invitedUser == null && userRepository.existsByPhoneNumber(phoneNumber)) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "This mobile number already belongs to an existing user. Search for them and add only the relationship.");
    }

    UserEntity entity = invitedUser == null ? new UserEntity() : invitedUser;
    entity.setUsername(username);
    entity.setEmail(email);
    entity.setPhoneNumber(phoneNumber);
    entity.setPasswordHash(passwordEncoder.encode(password));
    entity.setFirstName(optionalText(request.getFirstName()));
    entity.setSurname(optionalText(request.getSurname()));
    entity.setLocation(optionalText(request.getLocation()));
    entity.setAccountStatus("ACTIVE");
    return toDto(userRepository.save(entity));
  }

  public UserDto updateUser(Long id, CreateUserRequest request) {
    UserEntity entity = userRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("User not found"));
    String username = requireValue(request.getUsername(), "Username");
    String email = optionalEmail(request.getEmail());
    String phoneNumber = normalizePhoneNumber(request.getPhoneNumber());

    if (!entity.getUsername().equals(username) && userRepository.existsByUsername(username)) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "Username is already in use");
    }
    if (email != null && !email.equals(entity.getEmail()) && userRepository.existsByEmail(email)) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "Email is already in use");
    }
    if (!entity.getPhoneNumber().equals(phoneNumber) && userRepository.existsByPhoneNumber(phoneNumber)) {
      throw new ResponseStatusException(HttpStatus.CONFLICT, "This mobile number already belongs to an existing user. Search for them and add only the relationship.");
    }

    entity.setUsername(username);
    entity.setEmail(email);
    entity.setPhoneNumber(phoneNumber);
    entity.setFirstName(optionalText(request.getFirstName()));
    entity.setSurname(optionalText(request.getSurname()));
    entity.setLocation(optionalText(request.getLocation()));
    if (request.getPassword() != null && !request.getPassword().isBlank()) {
      entity.setPasswordHash(passwordEncoder.encode(validatePassword(request.getPassword())));
    }
    return toDto(userRepository.save(entity));
  }

  public void deleteUser(Long id) {
    userRepository.deleteById(id);
  }

  private UserDto toDto(UserEntity entity) {
    UserDto dto = new UserDto();
    dto.setId(entity.getId());
    dto.setUsername(entity.getUsername());
    dto.setEmail(entity.getEmail());
    dto.setPhoneNumber(entity.getPhoneNumber());
    dto.setRole(entity.getRole());
    dto.setFirstName(entity.getFirstName());
    dto.setSurname(entity.getSurname());
    dto.setLocation(entity.getLocation());
    return dto;
  }

  private String requireValue(String value, String fieldName) {
    if (value == null || value.isBlank()) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, fieldName + " is required");
    }
    return value.trim();
  }

  private String optionalEmail(String value) {
    if (value == null || value.isBlank()) {
      return null;
    }
    return value.trim().toLowerCase();
  }

  private String optionalText(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }

  private String normalizePhoneNumber(String value) {
    String phoneNumber = requireValue(value, "Phone number").replaceAll("[\\s()-]", "");
    if (!phoneNumber.matches("\\+?[0-9]{7,15}")) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Phone number must contain 7 to 15 digits");
    }
    return phoneNumber;
  }

  private String validatePassword(String value) {
    String password = requireValue(value, "Password");
    if (password.length() < 8 || password.length() > 128
        || !password.matches(".*[A-Za-z].*") || !password.matches(".*[0-9].*")) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
          "Password must be 8 to 128 characters and contain both letters and numbers");
    }
    return password;
  }
}

package com.myaaptha.config;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class ApiInputValidatorTest {
  private final ApiInputValidator validator = new ApiInputValidator();

  @Test
  void acceptsNormalNestedRequestData() {
    assertDoesNotThrow(() -> validator.validateBody(Map.of(
        "displayName", "Rambabu", "email", "rambabu@example.com",
        "phoneNumber", "+91 98765 43210", "messages", List.of(Map.of("message", "Hello")))));
  }

  @Test
  void rejectsOversizedSearchAndMessageValues() {
    assertThrows(ResponseStatusException.class, () -> validator.validateParameter("q", "x".repeat(201)));
    assertThrows(ResponseStatusException.class, () -> validator.validateBody(Map.of("message", "x".repeat(4001))));
  }

  @Test
  void rejectsControlCharactersAndMalformedContactValues() {
    assertThrows(ResponseStatusException.class, () -> validator.validateBody(Map.of("name", "bad\u0000value")));
    assertThrows(ResponseStatusException.class, () -> validator.validateBody(Map.of("email", "not-an-email")));
    assertThrows(ResponseStatusException.class, () -> validator.validateBody(Map.of("phoneNumber", "123")));
  }

  @Test
  void rejectsNonPositiveIdentifiersAndOversizedCollections() {
    assertThrows(ResponseStatusException.class, () -> validator.validateBody(Map.of("userId", 0)));
    assertThrows(ResponseStatusException.class,
        () -> validator.validateBody(Map.of("items", java.util.Collections.nCopies(1001, "value"))));
  }
}

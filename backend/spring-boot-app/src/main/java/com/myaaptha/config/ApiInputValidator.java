package com.myaaptha.config;

import java.lang.reflect.RecordComponent;
import java.util.Collection;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class ApiInputValidator {
  private static final int MAX_DEPTH = 12;
  private static final int MAX_NODES = 10_000;
  private static final int MAX_COLLECTION_ITEMS = 1_000;
  private static final int DEFAULT_TEXT_LIMIT = 10_000;
  private static final Pattern CONTROL_CHARACTERS = Pattern.compile("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]");
  private static final Set<String> POSITIVE_ID_NAMES = Set.of("id", "userId", "circleId", "postId", "messageId",
      "memberUserId", "otherUserId", "recipientId", "ownerUserId", "reportedUserId", "entityId", "targetId",
      "sourcePostId", "anchorUserId", "relativeToUserId", "relatedUserId", "parentPostId", "replyToMessageId");

  public void validateParameter(String name, String value) {
    if (name == null || name.length() > 100) reject("Invalid parameter name");
    validateString(name, value);
    if (POSITIVE_ID_NAMES.contains(name) && value != null && !value.isBlank()) {
      try {
        if (Long.parseLong(value) <= 0) reject(name + " must be a positive number");
      } catch (NumberFormatException exception) {
        reject(name + " must be a valid number");
      }
    }
  }

  public void validateBody(Object body) {
    walk(body, "request", 0, new int[] {0}, new IdentityHashMap<>());
  }

  private void walk(Object value, String field, int depth, int[] nodes, IdentityHashMap<Object, Boolean> visited) {
    if (value instanceof String text) { validateString(field, text); return; }
    if (value == null) return;
    if (value instanceof Number number) {
      if (POSITIVE_ID_NAMES.contains(field) && number.longValue() <= 0) reject(field + " must be a positive number");
      return;
    }
    if (isScalar(value)) return;
    if (depth > MAX_DEPTH || ++nodes[0] > MAX_NODES) reject("Request structure is too large");
    if (visited.put(value, Boolean.TRUE) != null) return;
    if (value instanceof Collection<?> collection) {
      if (collection.size() > MAX_COLLECTION_ITEMS) reject(field + " has too many items");
      int index = 0;
      for (Object item : collection) walk(item, field + "[" + index++ + "]", depth + 1, nodes, visited);
      return;
    }
    if (value instanceof Map<?, ?> map) {
      if (map.size() > MAX_COLLECTION_ITEMS) reject(field + " has too many entries");
      for (Map.Entry<?, ?> entry : map.entrySet()) {
        String key = String.valueOf(entry.getKey());
        validateString("field name", key);
        walk(entry.getValue(), key, depth + 1, nodes, visited);
      }
      return;
    }
    Class<?> type = value.getClass();
    if (type.isRecord()) {
      for (RecordComponent component : type.getRecordComponents()) {
        try {
          walk(component.getAccessor().invoke(value), component.getName(), depth + 1, nodes, visited);
        } catch (ReflectiveOperationException exception) {
          reject("Request could not be validated");
        }
      }
      return;
    }
    if (type.getPackageName().startsWith("com.myaaptha")) {
      for (var fieldValue : type.getDeclaredFields()) {
        if (java.lang.reflect.Modifier.isStatic(fieldValue.getModifiers())) continue;
        try {
          fieldValue.setAccessible(true);
          walk(fieldValue.get(value), fieldValue.getName(), depth + 1, nodes, visited);
        } catch (ReflectiveOperationException exception) {
          reject("Request could not be validated");
        }
      }
    }
  }

  private void validateString(String field, String value) {
    if (value == null) return;
    int limit = limitFor(field);
    if (value.length() > limit) reject(field + " must be " + limit + " characters or fewer");
    if (CONTROL_CHARACTERS.matcher(value).find()) reject(field + " contains unsupported control characters");
    String normalized = field == null ? "" : field.toLowerCase();
    String trimmed = value.trim();
    if (normalized.contains("email") && !trimmed.isEmpty()
        && !trimmed.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) reject(field + " must be a valid email address");
    if (normalized.contains("phone") && !trimmed.isEmpty()) {
      String digits = trimmed.replaceAll("\\D", "");
      if (digits.length() < 7 || digits.length() > 15) reject(field + " must be a valid phone number");
    }
    if (normalized.contains("password") && !value.isEmpty() && value.length() < 6) reject(field + " must be at least 6 characters");
  }

  private int limitFor(String field) {
    String normalized = field == null ? "" : field.replaceAll("\\[\\d+\\]", "").toLowerCase();
    if (normalized.contains("password")) return 128;
    if (normalized.contains("email")) return 254;
    if (normalized.contains("phone")) return 32;
    if (normalized.equals("q") || normalized.contains("query") || normalized.contains("search")) return 200;
    if (normalized.contains("token") || normalized.equals("code") || normalized.equals("state")) return 16_384;
    if (normalized.contains("sdp")) return 131_072;
    if (normalized.contains("url")) return 2_048;
    if (normalized.contains("name") || normalized.contains("title") || normalized.contains("type") || normalized.contains("status") || normalized.contains("kind") || normalized.contains("category")) return 255;
    if (normalized.contains("message") || normalized.contains("caption") || normalized.contains("description") || normalized.contains("notes") || normalized.contains("reason") || normalized.contains("details") || normalized.contains("body") || normalized.contains("bio")) return 4_000;
    return DEFAULT_TEXT_LIMIT;
  }

  private boolean isScalar(Object value) {
    return value instanceof Number || value instanceof Boolean || value instanceof Character || value instanceof Enum<?>
        || value instanceof java.time.temporal.Temporal || value instanceof java.util.UUID;
  }

  private void reject(String message) {
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
  }
}

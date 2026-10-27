package com.myaaptha.platform.state;

import java.time.Duration;
import java.util.List;

/** Shared, expiring state only. Never use this store as the source of record. */
public interface EphemeralState {
  long increment(String key, Duration ttl);
  void put(String key, String value, Duration ttl);
  String get(String key);
  List<String> getAll(List<String> keys);
  void delete(String key);
  /** Removes a live value only if it still equals the value the caller validated. */
  boolean deleteIfValue(String key, String expectedValue);
}

package com.myaaptha.platform.media;

import java.net.URI;
import java.time.Duration;
import org.springframework.core.io.Resource;

public interface MediaObjectStorage {
  void put(String key, byte[] bytes, String contentType, String originalName);
  Resource load(String key);
  void delete(String key);
  URI signedGetUrl(String key, Duration validity);
}

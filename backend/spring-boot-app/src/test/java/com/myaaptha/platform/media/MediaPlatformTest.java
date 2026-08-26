package com.myaaptha.platform.media;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.server.ResponseStatusException;

class MediaPlatformTest {
  @TempDir Path directory;

  @Test void localStorageWritesLoadsAndDeletesOutsideTheApplicationPackage() throws Exception {
    var storage=new LocalMediaObjectStorage(directory.toString());
    storage.put("profiles/photo.txt","safe".getBytes(),"text/plain","photo.txt");
    assertThat(storage.load("profiles/photo.txt").getContentAsString(java.nio.charset.StandardCharsets.UTF_8)).isEqualTo("safe");
    storage.delete("profiles/photo.txt");
    assertThatThrownBy(()->storage.load("profiles/photo.txt")).isInstanceOf(ResponseStatusException.class);
  }

  @Test void scannerRejectsExecutableAndEicarPayloads() {
    var scanner=new BasicMediaScanner();
    assertThatThrownBy(()->scanner.assertClean(new byte[]{0x4d,0x5a,0x00},"fake.jpg","image/jpeg")).isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(()->scanner.assertClean("EICAR-STANDARD-ANTIVIRUS-TEST-FILE".getBytes(),"test.txt","text/plain")).isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(()->scanner.assertClean("<svg onload=javascript:alert(1)>".getBytes(),"attack.svg","image/svg+xml")).isInstanceOf(ResponseStatusException.class);
    assertThatThrownBy(()->scanner.assertClean("#!/bin/sh\necho hacked".getBytes(),"audio.mp3","audio/mpeg")).isInstanceOf(ResponseStatusException.class);
    scanner.assertClean("ordinary document".getBytes(),"safe.txt","text/plain");
  }
}

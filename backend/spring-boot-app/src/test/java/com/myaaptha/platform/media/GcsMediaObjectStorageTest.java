package com.myaaptha.platform.media;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import com.google.cloud.storage.*;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.web.server.ResponseStatusException;

class GcsMediaObjectStorageTest {
  @Test void writesToOnlyTheConfiguredBucketAndStripsHeaderCharacters() {
    Storage client = mock(Storage.class);
    var store = new GcsMediaObjectStorage(client, "private-beta-media");
    byte[] bytes = "synthetic".getBytes(java.nio.charset.StandardCharsets.UTF_8);
    store.put("owner-12/file", bytes, "text/plain", "notes\r\n\".txt");
    var info = ArgumentCaptor.forClass(BlobInfo.class);
    verify(client).create(info.capture(), eq(bytes));
    assertEquals("private-beta-media", info.getValue().getBucket());
    assertEquals("owner-12/file", info.getValue().getName());
    assertEquals("inline; filename=\"notes.txt\"", info.getValue().getContentDisposition());
    assertEquals("text/plain", info.getValue().getContentType());
  }

  @Test void aMissingPrivateObjectIsNotFoundAndNeverFallsBackToPublicStorage() {
    Storage client = mock(Storage.class);
    var store = new GcsMediaObjectStorage(client, "private-beta-media");
    var error = assertThrows(ResponseStatusException.class, () -> store.load("missing"));
    assertEquals(404, error.getStatusCode().value());
    verify(client).get(BlobId.of("private-beta-media", "missing"));
    verifyNoMoreInteractions(client);
  }

  @Test void readsArePinnedToTheInspectedGeneration() throws Exception {
    Storage client = mock(Storage.class);
    Blob blob = mock(Blob.class);
    BlobId generation = BlobId.of("private-beta-media", "file", 42L);
    when(client.get(BlobId.of("private-beta-media", "file"))).thenReturn(blob);
    when(blob.getBlobId()).thenReturn(generation);
    when(blob.getSize()).thenReturn(7L);
    var resource = new GcsMediaObjectStorage(client, "private-beta-media").load("file");
    assertEquals(7, resource.contentLength());
    verify(client, never()).reader(any(BlobId.class));
    var channel = mock(com.google.cloud.ReadChannel.class);
    when(client.reader(generation)).thenReturn(channel);
    try (var stream = resource.getInputStream()) {
      verify(client).reader(generation);
    }
    verify(channel).close();
  }

  @Test void rejectsUnboundedSignedUrlsBeforeContactingTheProvider() {
    Storage client = mock(Storage.class);
    var store = new GcsMediaObjectStorage(client, "private-beta-media");
    for (Duration duration : new Duration[]{Duration.ZERO, Duration.ofNanos(1), Duration.ofSeconds(-1), Duration.ofDays(1)})
      assertThrows(IllegalArgumentException.class, () -> store.signedGetUrl("file", duration));
    verifyNoInteractions(client);
  }
}

package com.myaaptha.platform.media;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.nio.file.*;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.server.ResponseStatusException;
class MediaDeletionTest {
 @TempDir Path directory;
 @Test void localFailureIsVisibleAndRetryable() throws Exception {
  var storage=new LocalMediaObjectStorage(directory.toString());
  Files.createDirectories(directory.resolve("blocked"));
  Files.writeString(directory.resolve("blocked/child"),"synthetic");
  assertThatThrownBy(()->storage.delete("blocked")).isInstanceOf(ResponseStatusException.class);
  assertThat(Files.exists(directory.resolve("blocked/child"))).isTrue();
  Files.delete(directory.resolve("blocked/child"));
  storage.delete("blocked"); storage.delete("blocked");
  assertThat(Files.exists(directory.resolve("blocked"))).isFalse();
 }
 @Test void failedOriginalDoesNotMarkDeleted() {
  var storage=mock(MediaObjectStorage.class); var assets=mock(MediaAssetRepository.class);
  var asset=asset();
  when(assets.findByStorageKeyAndDeletedAtIsNull("original")).thenReturn(Optional.of(asset));
  doThrow(new IllegalStateException("unavailable")).when(storage).delete("original");
  var service=new MediaAssetService(storage,assets,mock(MediaScanner.class),1024);
  assertThatThrownBy(()->service.delete("original")).isInstanceOf(IllegalStateException.class);
  assertThat(asset.getDeletedAt()).isNull(); verify(assets,never()).save(any());
  verify(storage,never()).delete("thumbnail");
 }
 @Test void failedThumbnailCanRetryAfterOriginalIsGone() {
  var storage=mock(MediaObjectStorage.class); var assets=mock(MediaAssetRepository.class);
  var asset=asset();
  when(assets.findByStorageKeyAndDeletedAtIsNull("original")).thenReturn(Optional.of(asset));
  doThrow(new IllegalStateException("unavailable")).doNothing().when(storage).delete("thumbnail");
  var service=new MediaAssetService(storage,assets,mock(MediaScanner.class),1024);
  assertThatThrownBy(()->service.delete("original")).isInstanceOf(IllegalStateException.class);
  assertThat(asset.getDeletedAt()).isNull(); verify(assets,never()).save(any());
  service.delete("original"); assertThat(asset.getDeletedAt()).isNotNull();
  verify(storage,times(2)).delete("original"); verify(storage,times(2)).delete("thumbnail");
  verify(assets).save(asset);
 }
 private MediaAssetEntity asset(){var asset=new MediaAssetEntity();asset.setStorageKey("original");asset.setThumbnailKey("thumbnail");return asset;}
}

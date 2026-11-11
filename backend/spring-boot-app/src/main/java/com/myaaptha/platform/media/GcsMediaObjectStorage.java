package com.myaaptha.platform.media;

import com.google.cloud.ReadChannel;
import com.google.cloud.http.HttpTransportOptions;
import com.google.cloud.storage.*;
import java.net.URI;
import java.nio.channels.Channels;
import java.time.Duration;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.AbstractResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Private Google Cloud Storage, using ADC/workload credentials; no service-account key files. */
@Service
@ConditionalOnProperty(name="myaaptha.storage.provider", havingValue="gcs")
public class GcsMediaObjectStorage implements MediaObjectStorage {
  private final Storage storage;
  private final String bucket;

  @Autowired
  public GcsMediaObjectStorage(@Value("${myaaptha.storage.gcs.bucket}") String bucket) {
    this(StorageOptions.newBuilder().setTransportOptions(HttpTransportOptions.newBuilder()
        .setConnectTimeout(5000).setReadTimeout(30000).build()).build().getService(), bucket);
  }

  GcsMediaObjectStorage(Storage storage, String bucket) {
    if (bucket == null || !bucket.matches("[a-z0-9][a-z0-9._-]{1,220}[a-z0-9]"))
      throw new IllegalArgumentException("A valid private Google Cloud Storage bucket is required");
    this.storage = java.util.Objects.requireNonNull(storage);
    this.bucket = bucket;
  }

  public void put(String key, byte[] bytes, String contentType, String originalName) {
    // GCS encrypts every object at rest. Public access prevention and IAM are bucket controls.
    storage.create(info(key).setContentType(contentType)
        .setContentDisposition("inline; filename=\"" + safe(originalName) + "\"").build(), bytes);
  }

  public Resource load(String key) {
    Blob blob = storage.get(BlobId.of(bucket, key));
    if (blob == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Media not found");
    // Pin this read to its generation; a concurrent replacement must not change the response.
    BlobId version = blob.getBlobId();
    long size = blob.getSize();
    return new AbstractResource() {
      public String getDescription() { return "Private media object"; }
      public long contentLength() { return size; }
      public java.io.InputStream getInputStream() {
        ReadChannel channel = storage.reader(version);
        return Channels.newInputStream(channel);
      }
    };
  }

  public void delete(String key) { storage.delete(BlobId.of(bucket, key)); }

  public URI signedGetUrl(String key, Duration validity) {
    if (validity == null || validity.toSeconds() < 1
        || validity.compareTo(Duration.ofMinutes(15)) > 0)
      throw new IllegalArgumentException("Signed media URL validity must be between zero and 15 minutes");
    // IAM signBlob is additionally required for keyless signing. Normal media downloads use
    // the application's authenticated routes and do not need direct signed URLs.
    return URI.create(storage.signUrl(info(key).build(), validity.toSeconds(), TimeUnit.SECONDS,
        Storage.SignUrlOption.withV4Signature()).toString());
  }

  private BlobInfo.Builder info(String key) { return BlobInfo.newBuilder(BlobId.of(bucket, key)); }
  private static String safe(String name) {
    return name == null ? "file" : name.replace("\"", "").replace("\r", "").replace("\n", "");
  }
}

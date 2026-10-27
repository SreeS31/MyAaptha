package com.myaaptha.platform.media;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import software.amazon.awssdk.auth.credentials.EnvironmentVariableCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

/** Opt-in only: the Python harness creates and destroys this entire local service. */
@EnabledIfSystemProperty(named="myaaptha.s3.drill",matches="true")
class S3MediaRecoveryDrillTest {
  @Test void privateVersionedMediaCanBeDeletedAndRestoredWithoutLosingIntegrity() throws Exception {
    URI endpoint=URI.create(System.getenv("MYAAPTHA_S3_DRILL_ENDPOINT"));
    String bucket=System.getenv("MYAAPTHA_S3_DRILL_BUCKET");
    boolean encrypted=Boolean.parseBoolean(System.getenv("MYAAPTHA_S3_DRILL_TLS"));
    assertThat(endpoint.getScheme()).isEqualTo(encrypted?"https":"http");
    assertThat(endpoint.getHost()).isEqualTo("127.0.0.1");
    assertThat(endpoint.getPort()).isBetween(1024,65535);
    assertThat(bucket).matches("myaaptha-drill-[a-f0-9]{12}");
    assertThat(System.getenv("MYAAPTHA_S3_DISPOSABLE")).isEqualTo(bucket);
    try(var client=S3Client.builder().endpointOverride(endpoint).region(Region.US_EAST_1)
        .credentialsProvider(EnvironmentVariableCredentialsProvider.create()).forcePathStyle(true).build()) {
      // Creation must succeed; an already-existing bucket is never reused.
      client.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
      client.putBucketVersioning(PutBucketVersioningRequest.builder().bucket(bucket)
          .versioningConfiguration(VersioningConfiguration.builder().status(BucketVersioningStatus.ENABLED).build()).build());
      client.putBucketLifecycleConfiguration(PutBucketLifecycleConfigurationRequest.builder().bucket(bucket)
          .lifecycleConfiguration(BucketLifecycleConfiguration.builder().rules(LifecycleRule.builder()
              .id("synthetic-retention-contract").status(ExpirationStatus.ENABLED)
              .filter(LifecycleRuleFilter.builder().prefix("synthetic/").build())
              .expiration(LifecycleExpiration.builder().days(3).build())
              .noncurrentVersionExpiration(NoncurrentVersionExpiration.builder().noncurrentDays(2).build()).build()).build()).build());
      var rules=client.getBucketLifecycleConfiguration(GetBucketLifecycleConfigurationRequest.builder().bucket(bucket).build()).rules();
      assertThat(rules).hasSize(1);assertThat(rules.getFirst().expiration().days()).isEqualTo(3);
      assertThat(rules.getFirst().noncurrentVersionExpiration().noncurrentDays()).isEqualTo(2);
      String key="synthetic/recovery-fixture.txt";
      byte[] original="Synthetic media recovery fixture. No customer data.".repeat(200).getBytes(StandardCharsets.UTF_8);
      var storage=new S3MediaObjectStorage(bucket,"us-east-1",endpoint.toString());
      String version;
      if(encrypted){
        storage.put(key,original,"text/plain","synthetic.txt");
        var metadata=client.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build());
        assertThat(metadata.serverSideEncryption()).isEqualTo(ServerSideEncryption.AES256);
        version=metadata.versionId();
      }else{
        version=client.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType("text/plain").build(),RequestBody.fromBytes(original)).versionId();
      }
      assertThat(version).isNotBlank();
      assertThat(storage.load(key).contentLength()).isEqualTo(original.length);
      try(var stream=storage.load(key).getInputStream()){assertThat(stream.readAllBytes()).isEqualTo(original);}
      var http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
      assertThat(http.send(HttpRequest.newBuilder(endpoint.resolve("/"+bucket+"/"+key)).timeout(Duration.ofSeconds(15)).build(),HttpResponse.BodyHandlers.discarding()).statusCode()).isEqualTo(403);
      URI signed=storage.signedGetUrl(key,Duration.ofMinutes(2));
      var authorized=http.send(HttpRequest.newBuilder(signed).timeout(Duration.ofSeconds(15)).build(),HttpResponse.BodyHandlers.ofByteArray());
      assertThat(authorized.statusCode()).isEqualTo(200);assertThat(authorized.body()).isEqualTo(original);
      storage.delete(key);
      assertThatThrownBy(()->storage.load(key)).isInstanceOfSatisfying(S3Exception.class,error->assertThat(error.statusCode()).isEqualTo(404));
      assertThat(http.send(HttpRequest.newBuilder(signed).timeout(Duration.ofSeconds(15)).build(),HttpResponse.BodyHandlers.discarding()).statusCode()).isEqualTo(404);
      var versions=client.listObjectVersions(ListObjectVersionsRequest.builder().bucket(bucket).prefix(key).build());
      assertThat(versions.deleteMarkers()).hasSize(1);assertThat(versions.versions()).hasSize(1);
      assertThat(client.getObjectAsBytes(GetObjectRequest.builder().bucket(bucket).key(key).versionId(version).build()).asByteArray()).isEqualTo(original);
      var copy=CopyObjectRequest.builder().bucket(bucket).key(key).copySource(bucket+"/"+key+"?versionId="+version);
      if(encrypted)copy.serverSideEncryption(ServerSideEncryption.AES256);
      String restored=client.copyObject(copy.build()).versionId();
      if(encrypted)assertThat(client.headObject(HeadObjectRequest.builder().bucket(bucket).key(key).build()).serverSideEncryption()).isEqualTo(ServerSideEncryption.AES256);
      assertThat(restored).isNotBlank().isNotEqualTo(version);
      try(var stream=storage.load(key).getInputStream()){assertThat(stream.readAllBytes()).isEqualTo(original);}
      // Purge only versions created in this newly created synthetic bucket.
      versions=client.listObjectVersions(ListObjectVersionsRequest.builder().bucket(bucket).prefix(key).build());
      for(var item:versions.versions())client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).versionId(item.versionId()).build());
      for(var item:versions.deleteMarkers())client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).versionId(item.versionId()).build());
      var empty=client.listObjectVersions(ListObjectVersionsRequest.builder().bucket(bucket).build());
      assertThat(empty.versions()).isEmpty();assertThat(empty.deleteMarkers()).isEmpty();
      client.deleteBucket(DeleteBucketRequest.builder().bucket(bucket).build());
      new com.fasterxml.jackson.databind.ObjectMapper().writeValue(Path.of(System.getenv("MYAAPTHA_S3_DRILL_REPORT")).toFile(),Map.of(
          "schemaVersion",1,"unsignedReadDenied",true,"adapterLoadAndSignedRead",true,"versionedDeleteMarker",true,
          "restoredBytesMatch",true,"syntheticVersionsPurged",true,"lifecycleConfigurationRoundTrip",true,
          "automaticExpiryMeasured",false,"serverSideEncryptionExercised",encrypted,"releaseApproved",false));
    }
  }
}

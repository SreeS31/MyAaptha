package com.myaaptha.platform.media;

import java.net.URI;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

@Service
@ConditionalOnProperty(name="myaaptha.storage.provider",havingValue="s3")
public class S3MediaObjectStorage implements MediaObjectStorage {
  private final S3Client s3; private final S3Presigner presigner; private final String bucket;
  public S3MediaObjectStorage(@Value("${myaaptha.storage.s3.bucket}") String bucket,@Value("${myaaptha.storage.s3.region}") String region,@Value("${myaaptha.storage.s3.endpoint:}") String endpoint){
    this.bucket=bucket;var credentials=DefaultCredentialsProvider.create();var client=S3Client.builder().region(Region.of(region)).credentialsProvider(credentials);var signer=S3Presigner.builder().region(Region.of(region)).credentialsProvider(credentials);if(endpoint!=null&&!endpoint.isBlank()){client.endpointOverride(URI.create(endpoint));signer.endpointOverride(URI.create(endpoint));}s3=client.build();presigner=signer.build();
  }
  public void put(String key,byte[] bytes,String contentType,String originalName){s3.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType(contentType).contentDisposition("inline; filename=\""+safe(originalName)+"\"").serverSideEncryption(ServerSideEncryption.AES256).build(),RequestBody.fromBytes(bytes));}
  public Resource load(String key){byte[] bytes=s3.getObjectAsBytes(GetObjectRequest.builder().bucket(bucket).key(key).build()).asByteArray();return new ByteArrayResource(bytes);}
  public void delete(String key){s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());}
  public URI signedGetUrl(String key,Duration validity){var get=GetObjectRequest.builder().bucket(bucket).key(key).build();return URI.create(presigner.presignGetObject(GetObjectPresignRequest.builder().signatureDuration(validity).getObjectRequest(get).build()).url().toString());}
  private String safe(String value){return value==null?"file":value.replace("\"","").replace("\r","").replace("\n","");}
}

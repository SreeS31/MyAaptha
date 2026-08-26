package com.myaaptha.platform.media;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="media_assets")
public class MediaAssetEntity {
  @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
  @Column(name="owner_user_id",nullable=false) private Long ownerUserId;
  @Column(name="storage_key",nullable=false,unique=true,length=700) private String storageKey;
  @Column(nullable=false,length=40) private String category;
  @Column(name="original_name",nullable=false) private String originalName;
  @Column(name="content_type",nullable=false,length=150) private String contentType;
  @Column(name="size_bytes",nullable=false) private long sizeBytes;
  @Column(nullable=false,length=64) private String sha256;
  @Column(name="scan_status",nullable=false,length=24) private String scanStatus="CLEAN";
  @Column(name="thumbnail_key",length=700) private String thumbnailKey;
  @Column(name="expires_at") private Instant expiresAt;
  @Column(name="deleted_at") private Instant deletedAt;
  @Column(name="created_at",nullable=false) private Instant createdAt=Instant.now();
  public Long getId(){return id;} public Long getOwnerUserId(){return ownerUserId;} public void setOwnerUserId(Long v){ownerUserId=v;} public String getStorageKey(){return storageKey;} public void setStorageKey(String v){storageKey=v;} public String getCategory(){return category;} public void setCategory(String v){category=v;} public String getOriginalName(){return originalName;} public void setOriginalName(String v){originalName=v;} public String getContentType(){return contentType;} public void setContentType(String v){contentType=v;} public long getSizeBytes(){return sizeBytes;} public void setSizeBytes(long v){sizeBytes=v;} public String getSha256(){return sha256;} public void setSha256(String v){sha256=v;} public String getScanStatus(){return scanStatus;} public void setScanStatus(String v){scanStatus=v;} public String getThumbnailKey(){return thumbnailKey;} public void setThumbnailKey(String v){thumbnailKey=v;} public Instant getExpiresAt(){return expiresAt;} public void setExpiresAt(Instant v){expiresAt=v;} public Instant getDeletedAt(){return deletedAt;} public void setDeletedAt(Instant v){deletedAt=v;} public Instant getCreatedAt(){return createdAt;}
}

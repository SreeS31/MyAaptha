package com.circlenet.domain.trust;
import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="trusted_people",uniqueConstraints=@UniqueConstraint(columnNames={"owner_user_id","trusted_user_id","kind"})) public class TrustedPersonEntity {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id; @Column(name="owner_user_id",nullable=false) private Long ownerUserId; @Column(name="trusted_user_id",nullable=false) private Long trustedUserId; @Column(nullable=false,length=20) private String kind; @Column(name="created_at",nullable=false) private Instant createdAt=Instant.now();
 public Long getId(){return id;} public Long getOwnerUserId(){return ownerUserId;} public void setOwnerUserId(Long v){ownerUserId=v;} public Long getTrustedUserId(){return trustedUserId;} public void setTrustedUserId(Long v){trustedUserId=v;} public String getKind(){return kind;} public void setKind(String v){kind=v;} public Instant getCreatedAt(){return createdAt;}
}

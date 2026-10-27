package com.myaaptha.domain.node;

import com.myaaptha.domain.enums.Gender;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "person_nodes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PersonNode {

    @Id
    @Column(length = 36)
    private UUID id;

    @Column(name = "circle_id", nullable = false, length = 36)
    private UUID circleId;

    @Column(name = "parent_id", length = 36)
    private UUID parentId;

    @Column(name = "linked_user_id", length = 36)
    private UUID linkedUserId;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(name = "nick_name", length = 128)
    private String nickName;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private Gender gender = Gender.UNKNOWN;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "blood_group", length = 8)
    private String bloodGroup;

    private String occupation;
    private String company;
    private String designation;

    @Column(columnDefinition = "TEXT")
    private String education;

    private String nationality;
    private String religion;

    @Column(columnDefinition = "TEXT")
    private String biography;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "profile_picture_url", length = 512)
    private String profilePictureUrl;

    private String country;
    private String state;
    private String city;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Version
    @Builder.Default
    private Integer version = 0;

    @Column(name = "created_by", length = 36)
    private UUID createdBy;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        if (id == null) {
            id = UUID.randomUUID();
        }
    }
}

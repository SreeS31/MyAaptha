package com.myaaptha.domain.circle;

import com.myaaptha.domain.enums.CircleCategory;
import com.myaaptha.domain.enums.TreeType;
import com.myaaptha.domain.enums.Visibility;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "circles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Circle {

    @Id
    @Column(length = 36)
    private UUID id;

    @Column(name = "owner_id", nullable = false, length = 36)
    private UUID ownerId;

    @Column(nullable = false)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private CircleCategory category = CircleCategory.CUSTOM;

    @Enumerated(EnumType.STRING)
    @Column(name = "tree_type")
    @Builder.Default
    private TreeType treeType = TreeType.PRIVATE;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private Visibility visibility = Visibility.PRIVATE;

    @Column(name = "password_hash")
    private String passwordHash;

    @Builder.Default
    private Boolean archived = false;

    @Column(name = "health_score")
    @Builder.Default
    private Integer healthScore = 100;

    @Column(name = "member_count")
    @Builder.Default
    private Integer memberCount = 0;

    @Column(name = "node_count")
    @Builder.Default
    private Integer nodeCount = 0;

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

package com.myaaptha.domain.relationship;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "relationships")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Relationship {

    @Id
    @Column(length = 36)
    private UUID id;

    @Column(name = "circle_id", nullable = false, length = 36)
    private UUID circleId;

    @Column(name = "source_node_id", nullable = false, length = 36)
    private UUID sourceNodeId;

    @Column(name = "target_node_id", nullable = false, length = 36)
    private UUID targetNodeId;

    @Column(name = "relationship_type", nullable = false, length = 64)
    private String relationshipType;

    @Builder.Default
    private Boolean bidirectional = false;

    @Column(name = "created_by", length = 36)
    private UUID createdBy;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (id == null) {
            id = UUID.randomUUID();
        }
    }
}

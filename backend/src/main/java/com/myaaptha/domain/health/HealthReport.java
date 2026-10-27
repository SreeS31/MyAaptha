package com.myaaptha.domain.health;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "health_reports")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class HealthReport {
    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "report_date", nullable = false)
    private LocalDate reportDate;

    @Column(name = "file_name", nullable = false)
    private String fileName;

    @Column(name = "mime_type", nullable = false, length = 100)
    private String mimeType;

    @Column(name = "lab_name")
    private String labName;

    @Column(name = "summary", columnDefinition = "TEXT")
    private String summary;

    @Column(name = "created_at", updatable = false)
    @CreationTimestamp
    private Instant createdAt;

    @OneToMany(mappedBy = "report", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<LabResult> results = new ArrayList<>();

    @PrePersist
    void prePersist() {
        if (id == null) id = UUID.randomUUID();
    }

    public void addResult(LabResult result) {
        result.setReport(this);
        results.add(result);
    }
}

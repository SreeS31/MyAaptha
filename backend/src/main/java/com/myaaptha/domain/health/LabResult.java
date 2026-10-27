package com.myaaptha.domain.health;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "lab_results", indexes = {
        @Index(name = "idx_lab_result_name", columnList = "normalized_name")
})
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LabResult {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "report_id", nullable = false)
    private HealthReport report;

    @Column(name = "panel_name")
    private String panelName;

    @Column(name = "test_name", nullable = false)
    private String testName;

    @Column(name = "normalized_name", nullable = false)
    private String normalizedName;

    @Column(nullable = false)
    private Double value;

    @Column(length = 40)
    private String unit;

    @Column(name = "reference_low")
    private Double referenceLow;

    @Column(name = "reference_high")
    private Double referenceHigh;

    @Column(length = 20, nullable = false)
    private String status;

    @Column(columnDefinition = "TEXT")
    private String suggestion;
}

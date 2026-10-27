package com.myaaptha.service;

import com.myaaptha.domain.health.HealthReport;
import com.myaaptha.domain.health.LabResult;
import com.myaaptha.dto.health.HealthReportDtos.*;
import com.myaaptha.repository.HealthReportRepository;
import com.myaaptha.repository.LabResultRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class HealthReportService {
    private static final Set<String> ALLOWED_TYPES = Set.of("application/pdf", "image/jpeg", "image/png");
    private final HealthReportRepository reportRepository;
    private final LabResultRepository resultRepository;
    private final OpenAiHealthReportAnalyzer analyzer;

    @Transactional
    public ReportResponse upload(UUID userId, MultipartFile file) throws Exception {
        if (file.isEmpty()) throw new IllegalArgumentException("Choose a non-empty report file");
        if (!ALLOWED_TYPES.contains(file.getContentType())) {
            throw new IllegalArgumentException("Only PDF, JPEG and PNG reports are supported");
        }
        ExtractedReport extracted = analyzer.analyze(file);
        if (extracted.results() == null || extracted.results().isEmpty()) {
            throw new IllegalArgumentException("No numeric laboratory results were found in this report");
        }
        HealthReport report = HealthReport.builder()
                .userId(userId)
                .reportDate(extracted.reportDate() == null ? LocalDate.now() : extracted.reportDate())
                .fileName(Optional.ofNullable(file.getOriginalFilename()).orElse("health-report"))
                .mimeType(file.getContentType())
                .labName(extracted.labName())
                .summary(extracted.summary())
                .build();
        for (ExtractedResult item : extracted.results()) {
            if (item.testName() == null || item.value() == null) continue;
            report.addResult(LabResult.builder()
                    .panelName(item.panelName()).testName(item.testName())
                    .normalizedName(normalize(item.normalizedName(), item.testName()))
                    .value(item.value()).unit(item.unit())
                    .referenceLow(item.referenceLow()).referenceHigh(item.referenceHigh())
                    .status(status(item.value(), item.referenceLow(), item.referenceHigh()))
                    .suggestion(item.suggestion()).build());
        }
        return toResponse(reportRepository.save(report));
    }

    @Transactional(readOnly = true)
    public HealthHistory history(UUID userId) {
        List<ReportResponse> reports = reportRepository.findByUserIdOrderByReportDateDescCreatedAtDesc(userId)
                .stream().map(this::toResponse).toList();
        Map<String, List<LabResult>> grouped = resultRepository.findHistory(userId).stream()
                .collect(Collectors.groupingBy(LabResult::getNormalizedName, LinkedHashMap::new, Collectors.toList()));
        List<TestTrend> trends = grouped.values().stream().map(items -> {
            LabResult first = items.getFirst();
            List<TrendPoint> points = items.stream().map(item -> new TrendPoint(
                    item.getReport().getReportDate(), item.getValue(), item.getReferenceLow(),
                    item.getReferenceHigh(), item.getStatus(), item.getReport().getId())).toList();
            return new TestTrend(first.getNormalizedName(), first.getTestName(), first.getUnit(), points);
        }).toList();
        return new HealthHistory(reports, trends);
    }

    private ReportResponse toResponse(HealthReport report) {
        return new ReportResponse(report.getId(), report.getReportDate(), report.getFileName(),
                report.getLabName(), report.getSummary(), report.getResults().stream().map(item ->
                new ResultResponse(item.getId(), item.getPanelName(), item.getTestName(), item.getNormalizedName(),
                        item.getValue(), item.getUnit(), item.getReferenceLow(), item.getReferenceHigh(),
                        item.getStatus(), item.getSuggestion())).toList());
    }

    private String status(double value, Double low, Double high) {
        if (low != null && value < low) return "LOW";
        if (high != null && value > high) return "HIGH";
        return low == null && high == null ? "UNKNOWN" : "NORMAL";
    }

    private String normalize(String supplied, String fallback) {
        String value = supplied == null || supplied.isBlank() ? fallback : supplied;
        return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]+", "_").replaceAll("(^_+|_+$)", "");
    }
}

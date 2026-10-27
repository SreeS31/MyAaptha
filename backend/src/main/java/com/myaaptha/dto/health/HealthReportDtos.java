package com.myaaptha.dto.health;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class HealthReportDtos {
    private HealthReportDtos() {}

    public record ExtractedReport(LocalDate reportDate, String labName, String summary,
                                  List<ExtractedResult> results) {}
    public record ExtractedResult(String panelName, String testName, String normalizedName,
                                  Double value, String unit, Double referenceLow,
                                  Double referenceHigh, String suggestion) {}
    public record ResultResponse(Long id, String panelName, String testName, String normalizedName,
                                 Double value, String unit, Double referenceLow,
                                 Double referenceHigh, String status, String suggestion) {}
    public record ReportResponse(UUID id, LocalDate reportDate, String fileName, String labName,
                                 String summary, List<ResultResponse> results) {}
    public record TrendPoint(LocalDate date, Double value, Double referenceLow,
                             Double referenceHigh, String status, UUID reportId) {}
    public record TestTrend(String normalizedName, String testName, String unit,
                            List<TrendPoint> points) {}
    public record HealthHistory(List<ReportResponse> reports, List<TestTrend> trends) {}
}

package com.myaaptha.controller;

import com.myaaptha.dto.common.ApiResponse;
import com.myaaptha.dto.health.HealthReportDtos.HealthHistory;
import com.myaaptha.dto.health.HealthReportDtos.ReportResponse;
import com.myaaptha.service.HealthReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/health-reports")
@RequiredArgsConstructor
@Tag(name = "Health reports")
public class HealthReportController {
    private final HealthReportService service;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload and analyze a complete laboratory report")
    public ApiResponse<ReportResponse> upload(@RequestPart("file") MultipartFile file,
                                               Authentication auth) throws Exception {
        return ApiResponse.ok(service.upload(UUID.fromString(auth.getName()), file));
    }

    @GetMapping
    @Operation(summary = "Get report history and parameter trends")
    public ApiResponse<HealthHistory> history(Authentication auth) {
        return ApiResponse.ok(service.history(UUID.fromString(auth.getName())));
    }
}

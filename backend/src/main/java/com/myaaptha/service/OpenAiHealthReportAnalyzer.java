package com.myaaptha.service;

import com.myaaptha.dto.health.HealthReportDtos.ExtractedReport;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Base64;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class OpenAiHealthReportAnalyzer {
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).build();

    @Value("${openai.api-key:}")
    private String apiKey;
    @Value("${openai.model:gpt-4.1-mini}")
    private String model;

    public ExtractedReport analyze(MultipartFile file) throws Exception {
        if (apiKey.isBlank()) {
            throw new IllegalStateException("Report analysis is not configured. Set OPENAI_API_KEY.");
        }
        String mime = file.getContentType() == null ? MediaType.APPLICATION_PDF_VALUE : file.getContentType();
        String dataUrl = "data:" + mime + ";base64," + Base64.getEncoder().encodeToString(file.getBytes());
        Map<String, Object> documentInput = mime.startsWith("image/")
                ? Map.of("type", "input_image", "image_url", dataUrl, "detail", "high")
                : Map.of("type", "input_file", "filename", safeFilename(file), "file_data", dataUrl);
        Map<String, Object> payload = Map.of(
                "model", model,
                "input", new Object[]{Map.of(
                        "role", "user",
                        "content", new Object[]{
                                Map.of("type", "input_text", "text", extractionInstructions()),
                                documentInput
                        })},
                "text", Map.of("format", Map.of(
                        "type", "json_schema", "name", "health_report", "strict", true,
                        "schema", responseSchema()))
        );
        HttpRequest request = HttpRequest.newBuilder(URI.create("https://api.openai.com/v1/responses"))
                .timeout(Duration.ofMinutes(2))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(payload)))
                .build();
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() / 100 != 2) {
            throw new IllegalStateException("AI report analysis failed with status " + response.statusCode());
        }
        JsonNode root = objectMapper.readTree(response.body());
        for (JsonNode output : root.path("output")) {
            for (JsonNode content : output.path("content")) {
                if ("output_text".equals(content.path("type").asText())) {
                    return objectMapper.readValue(content.path("text").asText(), ExtractedReport.class);
                }
            }
        }
        throw new IllegalStateException("AI report analysis returned no structured results");
    }

    private String extractionInstructions() {
        return "Extract every numeric laboratory result from every page. Do not omit panel members such as lipid profile or CBP/CBC parameters. " +
                "Use the printed report date, lab name, units, and patient-specific reference ranges. normalizedName must be a stable lowercase snake_case medical test name. " +
                "Do not invent unreadable values. Give one short, cautious lifestyle suggestion only for results outside the supplied range; never diagnose or prescribe. " +
                "The summary must state that the analysis is informational and should be reviewed with a healthcare professional.";
    }

    private Map<String, Object> responseSchema() {
        Map<String, Object> nullableNumber = Map.of("type", new String[]{"number", "null"});
        Map<String, Object> nullableString = Map.of("type", new String[]{"string", "null"});
        Map<String, Object> result = Map.of(
                "type", "object", "additionalProperties", false,
                "required", new String[]{"panelName", "testName", "normalizedName", "value", "unit", "referenceLow", "referenceHigh", "suggestion"},
                "properties", Map.of("panelName", nullableString, "testName", Map.of("type", "string"),
                        "normalizedName", Map.of("type", "string"), "value", Map.of("type", "number"),
                        "unit", nullableString, "referenceLow", nullableNumber, "referenceHigh", nullableNumber,
                        "suggestion", nullableString));
        return Map.of("type", "object", "additionalProperties", false,
                "required", new String[]{"reportDate", "labName", "summary", "results"},
                "properties", Map.of("reportDate", Map.of("type", "string", "format", "date"),
                        "labName", nullableString, "summary", Map.of("type", "string"),
                        "results", Map.of("type", "array", "items", result)));
    }

    private String safeFilename(MultipartFile file) {
        String name = file.getOriginalFilename();
        return name == null || name.isBlank() ? "health-report" : name.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}

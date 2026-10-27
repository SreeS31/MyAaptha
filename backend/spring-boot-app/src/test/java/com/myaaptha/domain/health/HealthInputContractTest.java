package com.myaaptha.domain.health;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.LocalDate;
import java.util.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class HealthInputContractTest {
    final HealthService service = mock(HealthService.class);
    final ObjectMapper json = new ObjectMapper().findAndRegisterModules();
    MockMvc mvc;

    @BeforeEach void setup() {
        mvc = MockMvcBuilders.standaloneSetup(
            new HealthController(service, mock(HealthReportAnalyzer.class))).build();
    }

    Map<String, Object> input() {
        return new HashMap<>(Map.of("reportName", "Synthetic report",
            "collectedOn", LocalDate.now().minusDays(1).toString(),
            "measurements", List.of(Map.of("metricName", "Synthetic marker", "value", 10, "unit", "u"))));
    }

    @Test void rejectsInvalidReportFieldsBeforeSavingAnything() throws Exception {
        for (var invalid : List.<Map<String, Object>>of(
            Map.of("reportName", "x".repeat(201)),
            Map.of("collectedOn", LocalDate.now().plusDays(2).toString()),
            Map.of("measurements", List.of()),
            Map.of("measurements", Collections.singletonList(null)),
            Map.of("measurements", Collections.nCopies(501, Map.of("metricName", "Marker", "value", 1, "unit", "u"))),
            Map.of("sourcePostId", -1),Map.of("notes","x".repeat(1001)),Collections.singletonMap("collectedOn",null))) {
            var body = input(); body.putAll(invalid);
            mvc.perform(post("/api/health/reports").principal(() -> "1")
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)))
                .andExpect(status().isBadRequest());
        }
        verifyNoInteractions(service);
    }

    @Test void validatesNestedMeasurementBoundsBeforeSavingAnything() throws Exception {
        for (var invalid : List.<Map<String, Object>>of(
            Map.of("metricName", "x".repeat(121)),
            Map.of("value", 1000000001L),
            Map.of("unit", "x".repeat(41)),Map.of("suggestion","x".repeat(501)),Collections.singletonMap("value",null))) {
            var measurement = new HashMap<String, Object>(Map.of("metricName", "Marker", "value", 1, "unit", "u"));
            measurement.putAll(invalid);
            var body = input(); body.put("measurements", List.of(measurement));
            mvc.perform(post("/api/health/reports").principal(() -> "1")
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)))
                .andExpect(status().isBadRequest());
        }
        verifyNoInteractions(service);
    }

    @Test void exactStorageLimitsRemainAcceptedWithoutTruncationAtTheBoundary() throws Exception {
        var body=input();body.put("reportName","r".repeat(200));body.put("laboratory","l".repeat(200));body.put("notes","n".repeat(1000));
        body.put("measurements",List.of(Map.of("metricName","m".repeat(120),"unit","u".repeat(40),"value",0,"suggestion","s".repeat(500))));
        mvc.perform(post("/api/health/reports").principal(() -> "1").contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body))).andExpect(status().isOk());
        verify(service).add(eq(1L),any(HealthService.ReportInput.class));
    }

    @Test void acceptsValidManualReportAndPassesTheAuthenticatedOwner() throws Exception {
        mvc.perform(post("/api/health/reports").principal(() -> "17")
            .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(input())))
            .andExpect(status().isOk());
        verify(service).add(eq(17L), any(HealthService.ReportInput.class));
    }
}

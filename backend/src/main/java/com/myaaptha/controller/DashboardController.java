package com.myaaptha.controller;

import com.myaaptha.dto.common.ApiResponse;
import com.myaaptha.repository.CircleRepository;
import com.myaaptha.repository.PersonNodeRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/dashboard")
@RequiredArgsConstructor
@Tag(name = "Dashboard")
public class DashboardController {

    private final CircleRepository circleRepository;
    private final PersonNodeRepository nodeRepository;

    @GetMapping
    @Operation(summary = "Dashboard statistics for current user")
    public ApiResponse<DashboardStats> stats(Authentication auth) {
        UUID userId = UUID.fromString(auth.getName());
        long circles = circleRepository.countByOwnerId(userId);
        // Simplified: count all nodes in user's circles
        long members = circleRepository.findByOwnerId(userId, org.springframework.data.domain.Pageable.unpaged())
                .stream()
                .mapToLong(c -> nodeRepository.countByCircleId(c.getId()))
                .sum();

        return ApiResponse.ok(DashboardStats.builder()
                .totalCircles(circles)
                .totalMembers(members)
                .pendingInvitations(0)
                .build());
    }

    @Data
    @Builder
    public static class DashboardStats {
        private long totalCircles;
        private long totalMembers;
        private long pendingInvitations;
    }
}

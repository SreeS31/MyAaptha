package com.myaaptha.controller;

import com.myaaptha.dto.circle.CircleResponse;
import com.myaaptha.dto.circle.CreateCircleRequest;
import com.myaaptha.dto.common.ApiResponse;
import com.myaaptha.service.CircleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/circles")
@RequiredArgsConstructor
@Tag(name = "Circles")
public class CircleController {

    private final CircleService circleService;

    @PostMapping
    @Operation(summary = "Create a new circle")
    public ApiResponse<CircleResponse> create(Authentication auth,
                                              @Valid @RequestBody CreateCircleRequest request) {
        UUID userId = UUID.fromString(auth.getName());
        return ApiResponse.ok(circleService.create(userId, request));
    }

    @GetMapping
    @Operation(summary = "List circles for current user")
    public ApiResponse<Page<CircleResponse>> list(Authentication auth, Pageable pageable) {
        UUID userId = UUID.fromString(auth.getName());
        return ApiResponse.ok(circleService.listByOwner(userId, pageable));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get circle by ID")
    public ApiResponse<CircleResponse> getById(@PathVariable UUID id) {
        return ApiResponse.ok(circleService.getById(id));
    }
}

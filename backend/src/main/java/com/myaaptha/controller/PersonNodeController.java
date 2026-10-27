package com.myaaptha.controller;

import com.myaaptha.dto.common.ApiResponse;
import com.myaaptha.dto.node.CreateNodeRequest;
import com.myaaptha.dto.node.NodeResponse;
import com.myaaptha.engine.RelationshipEngine;
import com.myaaptha.service.PersonNodeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequiredArgsConstructor
@Tag(name = "Nodes")
public class PersonNodeController {

    private final PersonNodeService nodeService;
    private final RelationshipEngine relationshipEngine;

    @PostMapping("/api/v1/circles/{circleId}/nodes")
    @Operation(summary = "Add person node to circle")
    public ApiResponse<NodeResponse> create(@PathVariable UUID circleId,
                                            Authentication auth,
                                            @Valid @RequestBody CreateNodeRequest request) {
        UUID userId = UUID.fromString(auth.getName());
        return ApiResponse.ok(nodeService.create(circleId, userId, request));
    }

    @GetMapping("/api/v1/circles/{circleId}/nodes/roots")
    @Operation(summary = "Get root nodes of circle tree")
    public ApiResponse<List<NodeResponse>> getRoots(@PathVariable UUID circleId) {
        return ApiResponse.ok(nodeService.getRootNodes(circleId));
    }

    @GetMapping("/api/v1/circles/{circleId}/nodes/{parentId}/children")
    @Operation(summary = "Get child nodes (lazy load)")
    public ApiResponse<List<NodeResponse>> getChildren(@PathVariable UUID circleId,
                                                       @PathVariable UUID parentId) {
        return ApiResponse.ok(nodeService.getChildren(circleId, parentId));
    }

    @GetMapping("/api/v1/nodes/{id}")
    @Operation(summary = "Get node by ID")
    public ApiResponse<NodeResponse> getById(@PathVariable UUID id) {
        return ApiResponse.ok(nodeService.getById(id));
    }

    @GetMapping("/api/v1/circles/{circleId}/search")
    @Operation(summary = "Search nodes in circle")
    public ApiResponse<Page<NodeResponse>> search(@PathVariable UUID circleId,
                                                  @RequestParam String q,
                                                  Pageable pageable) {
        return ApiResponse.ok(nodeService.search(circleId, q, pageable));
    }

    @GetMapping("/api/v1/nodes/{fromId}/kinship/{toId}")
    @Operation(summary = "Resolve kinship between two nodes")
    public ApiResponse<RelationshipEngine.KinshipResult> kinship(@PathVariable UUID fromId,
                                                                 @PathVariable UUID toId) {
        return ApiResponse.ok(relationshipEngine.resolve(fromId, toId));
    }
}

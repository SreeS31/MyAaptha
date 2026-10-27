package com.myaaptha.service;

import com.myaaptha.domain.circle.Circle;
import com.myaaptha.dto.circle.CircleResponse;
import com.myaaptha.dto.circle.CreateCircleRequest;
import com.myaaptha.exception.ResourceNotFoundException;
import com.myaaptha.repository.CircleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CircleService {

    private final CircleRepository circleRepository;

    @Transactional
    public CircleResponse create(UUID ownerId, CreateCircleRequest request) {
        Circle circle = Circle.builder()
                .ownerId(ownerId)
                .name(request.getName())
                .description(request.getDescription())
                .category(request.getCategory())
                .treeType(request.getTreeType())
                .visibility(request.getVisibility())
                .build();
        circle = circleRepository.save(circle);
        return toResponse(circle);
    }

    @Transactional(readOnly = true)
    public CircleResponse getById(UUID id) {
        return circleRepository.findById(id)
                .map(this::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Circle not found"));
    }

    @Transactional(readOnly = true)
    public Page<CircleResponse> listByOwner(UUID ownerId, Pageable pageable) {
        return circleRepository.findByOwnerIdAndArchivedFalse(ownerId, pageable)
                .map(this::toResponse);
    }

    private CircleResponse toResponse(Circle circle) {
        return CircleResponse.builder()
                .id(circle.getId())
                .name(circle.getName())
                .description(circle.getDescription())
                .category(circle.getCategory())
                .treeType(circle.getTreeType())
                .visibility(circle.getVisibility())
                .healthScore(circle.getHealthScore())
                .memberCount(circle.getMemberCount())
                .nodeCount(circle.getNodeCount())
                .archived(circle.getArchived())
                .createdAt(circle.getCreatedAt())
                .build();
    }
}

package com.myaaptha.service;

import com.myaaptha.domain.node.PersonNode;
import com.myaaptha.dto.node.CreateNodeRequest;
import com.myaaptha.dto.node.NodeResponse;
import com.myaaptha.exception.ResourceNotFoundException;
import com.myaaptha.repository.CircleRepository;
import com.myaaptha.repository.PersonNodeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PersonNodeService {

    private final PersonNodeRepository nodeRepository;
    private final CircleRepository circleRepository;

    @Transactional
    public NodeResponse create(UUID circleId, UUID userId, CreateNodeRequest request) {
        if (!circleRepository.existsById(circleId)) {
            throw new ResourceNotFoundException("Circle not found");
        }

        PersonNode node = PersonNode.builder()
                .circleId(circleId)
                .parentId(request.getParentId())
                .fullName(request.getFullName())
                .nickName(request.getNickName())
                .gender(request.getGender())
                .dateOfBirth(request.getDateOfBirth())
                .occupation(request.getOccupation())
                .company(request.getCompany())
                .city(request.getCity())
                .country(request.getCountry())
                .createdBy(userId)
                .build();

        node = nodeRepository.save(node);
        return toResponse(node);
    }

    @Transactional(readOnly = true)
    public NodeResponse getById(UUID id) {
        return nodeRepository.findById(id)
                .map(this::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Node not found"));
    }

    @Transactional(readOnly = true)
    public List<NodeResponse> getRootNodes(UUID circleId) {
        return nodeRepository.findByCircleIdAndParentIdIsNull(circleId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<NodeResponse> getChildren(UUID circleId, UUID parentId) {
        return nodeRepository.findByCircleIdAndParentId(circleId, parentId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public Page<NodeResponse> search(UUID circleId, String query, Pageable pageable) {
        return nodeRepository.searchInCircle(circleId, query, pageable)
                .map(this::toResponse);
    }

    private NodeResponse toResponse(PersonNode node) {
        Integer age = null;
        if (node.getDateOfBirth() != null) {
            age = Period.between(node.getDateOfBirth(), LocalDate.now()).getYears();
        }
        return NodeResponse.builder()
                .id(node.getId())
                .circleId(node.getCircleId())
                .parentId(node.getParentId())
                .fullName(node.getFullName())
                .nickName(node.getNickName())
                .gender(node.getGender())
                .dateOfBirth(node.getDateOfBirth())
                .age(age)
                .occupation(node.getOccupation())
                .company(node.getCompany())
                .city(node.getCity())
                .profilePictureUrl(node.getProfilePictureUrl())
                .build();
    }
}

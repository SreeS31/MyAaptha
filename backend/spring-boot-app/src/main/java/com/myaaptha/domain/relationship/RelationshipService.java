package com.myaaptha.domain.relationship;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.myaaptha.domain.relationship.dto.CreateRelationshipRequest;
import com.myaaptha.domain.relationship.dto.RelationshipDto;
import com.myaaptha.domain.relationship.model.RelationshipEntity;

@Service
public class RelationshipService {
  private final RelationshipRepository relationshipRepository;

  public RelationshipService(RelationshipRepository relationshipRepository) {
    this.relationshipRepository = relationshipRepository;
  }

  public List<RelationshipDto> listRelationships() {
    return relationshipRepository.findAll().stream().map(this::toDto).collect(Collectors.toList());
  }

  public RelationshipDto getRelationship(Long id) {
    return relationshipRepository.findById(id).map(this::toDto).orElseThrow(() -> new IllegalArgumentException("Relationship not found"));
  }

  public RelationshipDto createRelationship(CreateRelationshipRequest request) {
    RelationshipEntity entity = new RelationshipEntity();
    entity.setType(request.getType());
    return toDto(relationshipRepository.save(entity));
  }

  public RelationshipDto updateRelationship(Long id, CreateRelationshipRequest request) {
    RelationshipEntity entity = relationshipRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Relationship not found"));
    entity.setType(request.getType());
    return toDto(relationshipRepository.save(entity));
  }

  public void deleteRelationship(Long id) {
    relationshipRepository.deleteById(id);
  }

  private RelationshipDto toDto(RelationshipEntity entity) {
    RelationshipDto dto = new RelationshipDto();
    dto.setId(entity.getId());
    dto.setType(entity.getType());
    return dto;
  }
}

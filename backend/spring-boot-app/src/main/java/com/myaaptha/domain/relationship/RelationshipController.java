package com.myaaptha.domain.relationship;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.myaaptha.domain.relationship.dto.CreateRelationshipRequest;
import com.myaaptha.domain.relationship.dto.RelationshipDto;

@RestController
@RequestMapping("/api/relationships")
public class RelationshipController {
  private final RelationshipService relationshipService;

  public RelationshipController(RelationshipService relationshipService) {
    this.relationshipService = relationshipService;
  }

  @GetMapping
  public List<RelationshipDto> listRelationships() {
    return relationshipService.listRelationships();
  }

  @GetMapping("/{id}")
  public ResponseEntity<RelationshipDto> getRelationship(@PathVariable Long id) {
    try {
      return ResponseEntity.ok(relationshipService.getRelationship(id));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @PostMapping
  public RelationshipDto createRelationship(@RequestBody CreateRelationshipRequest request) {
    return relationshipService.createRelationship(request);
  }

  @PutMapping("/{id}")
  public ResponseEntity<RelationshipDto> updateRelationship(@PathVariable Long id, @RequestBody CreateRelationshipRequest request) {
    try {
      return ResponseEntity.ok(relationshipService.updateRelationship(id, request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @DeleteMapping("/{id}")
  public ResponseEntity<Void> deleteRelationship(@PathVariable Long id) {
    try {
      relationshipService.deleteRelationship(id);
      return ResponseEntity.noContent().build();
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }
}

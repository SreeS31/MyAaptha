package com.myaaptha.domain.milestone;

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
import org.springframework.web.bind.annotation.RequestParam;

import com.myaaptha.domain.milestone.dto.BulkMilestoneStatusRequest;
import com.myaaptha.domain.milestone.dto.CreateMilestoneRequest;
import com.myaaptha.domain.milestone.dto.MilestoneDto;

@RestController
@RequestMapping("/api/milestones")
public class MilestoneController {
  private final MilestoneService milestoneService;

  public MilestoneController(MilestoneService milestoneService) {
    this.milestoneService = milestoneService;
  }

  @GetMapping
  public List<MilestoneDto> listMilestones(@RequestParam(required = false) Long projectId) {
    return milestoneService.listMilestones(projectId);
  }

  @GetMapping("/{id}")
  public ResponseEntity<MilestoneDto> getMilestone(@PathVariable Long id) {
    try {
      return ResponseEntity.ok(milestoneService.getMilestone(id));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @PostMapping
  public MilestoneDto createMilestone(@RequestBody CreateMilestoneRequest request) {
    return milestoneService.createMilestone(request);
  }

  @PutMapping("/{id}")
  public ResponseEntity<MilestoneDto> updateMilestone(@PathVariable Long id, @RequestBody CreateMilestoneRequest request) {
    try {
      return ResponseEntity.ok(milestoneService.updateMilestone(id, request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @PostMapping("/bulk-status")
  public ResponseEntity<List<MilestoneDto>> bulkUpdateStatus(@RequestBody BulkMilestoneStatusRequest request) {
    try {
      return ResponseEntity.ok(milestoneService.bulkUpdateStatus(request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.badRequest().build();
    }
  }

  @DeleteMapping("/{id}")
  public ResponseEntity<Void> deleteMilestone(@PathVariable Long id) {
    try {
      milestoneService.deleteMilestone(id);
      return ResponseEntity.noContent().build();
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }
}

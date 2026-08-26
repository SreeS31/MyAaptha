package com.myaaptha.domain.circle;

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

import com.myaaptha.domain.circle.dto.CircleDto;
import com.myaaptha.domain.circle.dto.CreateCircleRequest;

@RestController
@RequestMapping("/api/circles")
public class CircleController {
  private final CircleService circleService;

  public CircleController(CircleService circleService) {
    this.circleService = circleService;
  }

  @GetMapping
  public List<CircleDto> listCircles() {
    return circleService.listCircles();
  }

  @GetMapping("/{id}")
  public ResponseEntity<CircleDto> getCircle(@PathVariable Long id) {
    try {
      return ResponseEntity.ok(circleService.getCircle(id));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @PostMapping
  public CircleDto createCircle(@RequestBody CreateCircleRequest request) {
    return circleService.createCircle(request);
  }

  @PutMapping("/{id}")
  public ResponseEntity<CircleDto> updateCircle(@PathVariable Long id, @RequestBody CreateCircleRequest request) {
    try {
      return ResponseEntity.ok(circleService.updateCircle(id, request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @DeleteMapping("/{id}")
  public ResponseEntity<Void> deleteCircle(@PathVariable Long id) {
    try {
      circleService.deleteCircle(id);
      return ResponseEntity.noContent().build();
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }
}

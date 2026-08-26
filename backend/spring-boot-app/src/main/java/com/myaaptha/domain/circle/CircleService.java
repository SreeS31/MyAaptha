package com.myaaptha.domain.circle;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.myaaptha.domain.circle.dto.CircleDto;
import com.myaaptha.domain.circle.dto.CreateCircleRequest;
import com.myaaptha.domain.circle.model.CircleEntity;

@Service
public class CircleService {
  private final CircleRepository circleRepository;

  public CircleService(CircleRepository circleRepository) {
    this.circleRepository = circleRepository;
  }

  public List<CircleDto> listCircles() {
    return circleRepository.findAll().stream().map(this::toDto).collect(Collectors.toList());
  }

  public CircleDto getCircle(Long id) {
    return circleRepository.findById(id).map(this::toDto).orElseThrow(() -> new IllegalArgumentException("Circle not found"));
  }

  public CircleDto createCircle(CreateCircleRequest request) {
    CircleEntity entity = new CircleEntity();
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    return toDto(circleRepository.save(entity));
  }

  public CircleDto updateCircle(Long id, CreateCircleRequest request) {
    CircleEntity entity = circleRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Circle not found"));
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    return toDto(circleRepository.save(entity));
  }

  public void deleteCircle(Long id) {
    circleRepository.deleteById(id);
  }

  private CircleDto toDto(CircleEntity entity) {
    CircleDto dto = new CircleDto();
    dto.setId(entity.getId());
    dto.setName(entity.getName());
    dto.setDescription(entity.getDescription());
    return dto;
  }
}

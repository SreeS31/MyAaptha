package com.myaaptha.domain.permission;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.myaaptha.domain.permission.dto.CreatePermissionRequest;
import com.myaaptha.domain.permission.dto.PermissionDto;
import com.myaaptha.domain.permission.model.PermissionEntity;

@Service
public class PermissionService {
  private final PermissionRepository permissionRepository;

  public PermissionService(PermissionRepository permissionRepository) {
    this.permissionRepository = permissionRepository;
  }

  public List<PermissionDto> listPermissions() {
    return permissionRepository.findAll().stream().map(this::toDto).collect(Collectors.toList());
  }

  public PermissionDto getPermission(Long id) {
    return permissionRepository.findById(id).map(this::toDto).orElseThrow(() -> new IllegalArgumentException("Permission not found"));
  }

  public PermissionDto createPermission(CreatePermissionRequest request) {
    PermissionEntity entity = new PermissionEntity();
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    return toDto(permissionRepository.save(entity));
  }

  public PermissionDto updatePermission(Long id, CreatePermissionRequest request) {
    PermissionEntity entity = permissionRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Permission not found"));
    entity.setName(request.getName());
    entity.setDescription(request.getDescription());
    return toDto(permissionRepository.save(entity));
  }

  public void deletePermission(Long id) {
    permissionRepository.deleteById(id);
  }

  private PermissionDto toDto(PermissionEntity entity) {
    PermissionDto dto = new PermissionDto();
    dto.setId(entity.getId());
    dto.setName(entity.getName());
    dto.setDescription(entity.getDescription());
    return dto;
  }
}

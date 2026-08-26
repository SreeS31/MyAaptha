package com.myaaptha.domain.permission;

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

import com.myaaptha.domain.permission.dto.CreatePermissionRequest;
import com.myaaptha.domain.permission.dto.PermissionDto;

@RestController
@RequestMapping("/api/permissions")
public class PermissionController {
  private final PermissionService permissionService;

  public PermissionController(PermissionService permissionService) {
    this.permissionService = permissionService;
  }

  @GetMapping
  public List<PermissionDto> listPermissions() {
    return permissionService.listPermissions();
  }

  @GetMapping("/{id}")
  public ResponseEntity<PermissionDto> getPermission(@PathVariable Long id) {
    try {
      return ResponseEntity.ok(permissionService.getPermission(id));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @PostMapping
  public PermissionDto createPermission(@RequestBody CreatePermissionRequest request) {
    return permissionService.createPermission(request);
  }

  @PutMapping("/{id}")
  public ResponseEntity<PermissionDto> updatePermission(@PathVariable Long id, @RequestBody CreatePermissionRequest request) {
    try {
      return ResponseEntity.ok(permissionService.updatePermission(id, request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @DeleteMapping("/{id}")
  public ResponseEntity<Void> deletePermission(@PathVariable Long id) {
    try {
      permissionService.deletePermission(id);
      return ResponseEntity.noContent().build();
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }
}

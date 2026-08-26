package com.myaaptha.domain.network.dto;

import java.util.List;

public record NetworkCircleDto(Long id, String name, String description, List<NetworkCircleMemberDto> members,
    String ownerName, String ownerPhoto, boolean ownedByCurrentUser, boolean currentUserAdmin,
    String postingPermission, boolean currentUserCanPost) {}

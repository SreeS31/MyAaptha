package com.myaaptha.dto.circle;

import com.myaaptha.domain.enums.CircleCategory;
import com.myaaptha.domain.enums.TreeType;
import com.myaaptha.domain.enums.Visibility;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class CircleResponse {
    private UUID id;
    private String name;
    private String description;
    private CircleCategory category;
    private TreeType treeType;
    private Visibility visibility;
    private Integer healthScore;
    private Integer memberCount;
    private Integer nodeCount;
    private Boolean archived;
    private Instant createdAt;
}

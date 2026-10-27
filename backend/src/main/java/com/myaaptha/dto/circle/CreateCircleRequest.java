package com.myaaptha.dto.circle;

import com.myaaptha.domain.enums.CircleCategory;
import com.myaaptha.domain.enums.TreeType;
import com.myaaptha.domain.enums.Visibility;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class CreateCircleRequest {
    @NotBlank
    private String name;
    private String description;
    private CircleCategory category;
    private TreeType treeType;
    private Visibility visibility;
}

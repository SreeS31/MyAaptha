package com.myaaptha.dto.node;

import com.myaaptha.domain.enums.Gender;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
public class NodeResponse {
    private UUID id;
    private UUID circleId;
    private UUID parentId;
    private String fullName;
    private String nickName;
    private Gender gender;
    private LocalDate dateOfBirth;
    private Integer age;
    private String occupation;
    private String company;
    private String city;
    private String profilePictureUrl;
}

package com.myaaptha.dto.node;

import com.myaaptha.domain.enums.Gender;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.time.LocalDate;
import java.util.UUID;

@Data
public class CreateNodeRequest {
    @NotBlank
    private String fullName;
    private String nickName;
    private Gender gender;
    private LocalDate dateOfBirth;
    private UUID parentId;
    private String occupation;
    private String company;
    private String city;
    private String country;
}

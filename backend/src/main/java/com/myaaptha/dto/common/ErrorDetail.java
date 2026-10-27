package com.myaaptha.dto.common;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ErrorDetail {
    private String code;
    private String message;
}

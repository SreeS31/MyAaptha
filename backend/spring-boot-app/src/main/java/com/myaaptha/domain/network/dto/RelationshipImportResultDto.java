package com.myaaptha.domain.network.dto;

import java.util.List;

public record RelationshipImportResultDto(int totalRows, int successCount, int errorCount,
    List<RelationshipImportRowResult> rows) {}

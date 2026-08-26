package com.myaaptha.domain.network;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import com.myaaptha.domain.network.dto.AddPersonRequest;
import com.myaaptha.domain.network.dto.NetworkRelationshipDto;
import com.myaaptha.domain.network.dto.RelationshipImportResultDto;
import com.myaaptha.domain.network.dto.RelationshipImportRowResult;

/**
 * Parses a bulk relationship upload (Excel or CSV) and creates the corresponding
 * relationship-tree entries one row at a time, reusing {@link NetworkService#addPerson}
 * so every created person goes through the same validation, invitation, and notification flow
 * as a manually added relationship.
 */
@Service
public class RelationshipBulkImportService {
  private static final int MAX_ROWS = 500;

  private static final Map<String, String> HEADER_ALIASES = Map.ofEntries(
      Map.entry("rowid", "rowId"),
      Map.entry("row", "rowId"),
      Map.entry("fullname", "fullName"),
      Map.entry("name", "fullName"),
      Map.entry("relationshiptoyou", "type"),
      Map.entry("relationshiptype", "type"),
      Map.entry("relationship", "type"),
      Map.entry("type", "type"),
      Map.entry("relativeto", "relativeTo"),
      Map.entry("relativetorowidoruserid", "relativeTo"),
      Map.entry("persontype", "identityType"),
      Map.entry("identitytype", "identityType"),
      Map.entry("managedcategory", "managedCategory"),
      Map.entry("mobilenumber", "phoneNumber"),
      Map.entry("phone", "phoneNumber"),
      Map.entry("phonenumber", "phoneNumber"),
      Map.entry("email", "email"),
      Map.entry("dateofbirth", "dateOfBirth"),
      Map.entry("dateofdeath", "dateOfDeath"),
      Map.entry("milestonedate", "milestoneDate"),
      Map.entry("visibilityscope", "visibilityScope"),
      Map.entry("visibilitycompany", "visibilityCompany"),
      Map.entry("notes", "notes"));

  private final NetworkService networkService;

  public RelationshipBulkImportService(NetworkService networkService) {
    this.networkService = networkService;
  }

  public RelationshipImportResultDto importFile(Long currentUserId, MultipartFile file) {
    if (file == null || file.isEmpty()) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose a file to upload");
    }
    List<Map<String, String>> rows = parse(file);
    if (rows.isEmpty()) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "The file has no data rows");
    }
    if (rows.size() > MAX_ROWS) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Upload at most " + MAX_ROWS + " rows at a time");
    }

    Map<String, Long> rowIdToUserId = new LinkedHashMap<>();
    List<RelationshipImportRowResult> results = new ArrayList<>();
    int successCount = 0;
    int rowNumber = 1;
    for (Map<String, String> row : rows) {
      rowNumber++;
      String fullName = value(row, "fullName");
      try {
        AddPersonRequest request = toRequest(row, rowIdToUserId, currentUserId);
        NetworkRelationshipDto created = networkService.addPerson(currentUserId, request);
        String rowId = value(row, "rowId");
        if (rowId != null && created.person() != null) {
          rowIdToUserId.put(rowId.toLowerCase(Locale.ROOT), created.person().id());
        }
        results.add(new RelationshipImportRowResult(rowNumber, fullName, true, "Added successfully",
            created.person() == null ? null : created.person().id(), created.id()));
        successCount++;
      } catch (ResponseStatusException ex) {
        results.add(new RelationshipImportRowResult(rowNumber, fullName, false, ex.getReason(), null, null));
      } catch (Exception ex) {
        results.add(new RelationshipImportRowResult(rowNumber, fullName, false, "Unexpected error: " + ex.getMessage(), null, null));
      }
    }
    return new RelationshipImportResultDto(rows.size(), successCount, rows.size() - successCount, results);
  }

  private AddPersonRequest toRequest(Map<String, String> row, Map<String, Long> rowIdToUserId, Long currentUserId) {
    Long relativeToUserId = resolveRelativeTo(value(row, "relativeTo"), rowIdToUserId);
    return new AddPersonRequest(
        value(row, "fullName"),
        value(row, "phoneNumber"),
        value(row, "email"),
        value(row, "type"),
        value(row, "visibilityScope"),
        value(row, "visibilityCompany"),
        value(row, "identityType"),
        value(row, "managedCategory"),
        value(row, "dateOfBirth"),
        value(row, "dateOfDeath"),
        value(row, "milestoneDate"),
        value(row, "notes"),
        relativeToUserId);
  }

  private Long resolveRelativeTo(String relativeTo, Map<String, Long> rowIdToUserId) {
    if (relativeTo == null || relativeTo.isBlank()) return null;
    String trimmed = relativeTo.trim();
    if (trimmed.matches("[0-9]+")) return Long.valueOf(trimmed);
    Long resolved = rowIdToUserId.get(trimmed.toLowerCase(Locale.ROOT));
    if (resolved == null) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
          "\"Relative To\" refers to row \"" + trimmed + "\" which was not found earlier in the file");
    }
    return resolved;
  }

  private String value(Map<String, String> row, String key) {
    String value = row.get(key);
    return value == null || value.isBlank() ? null : value.trim();
  }

  private List<Map<String, String>> parse(MultipartFile file) {
    String filename = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase(Locale.ROOT);
    try {
      if (filename.endsWith(".csv")) return parseCsv(file.getInputStream());
      return parseExcel(file.getInputStream());
    } catch (ResponseStatusException ex) {
      throw ex;
    } catch (Exception ex) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unable to read the uploaded file. Use the provided template.");
    }
  }

  private List<Map<String, String>> parseCsv(InputStream inputStream) throws IOException {
    List<Map<String, String>> rows = new ArrayList<>();
    try (CSVParser parser = CSVFormat.DEFAULT.builder().setHeader().setSkipHeaderRecord(true).setTrim(true)
        .setIgnoreHeaderCase(true).build().parse(new InputStreamReader(inputStream, StandardCharsets.UTF_8))) {
      Map<String, String> headerMap = normalizeHeaders(parser.getHeaderNames());
      for (CSVRecord record : parser) {
        Map<String, String> row = new LinkedHashMap<>();
        for (String header : parser.getHeaderNames()) {
          String canonical = headerMap.get(header);
          if (canonical != null) row.put(canonical, record.get(header));
        }
        if (row.values().stream().anyMatch(v -> v != null && !v.isBlank())) rows.add(row);
      }
    }
    return rows;
  }

  private List<Map<String, String>> parseExcel(InputStream inputStream) throws IOException {
    List<Map<String, String>> rows = new ArrayList<>();
    DataFormatter formatter = new DataFormatter();
    try (Workbook workbook = WorkbookFactory.create(inputStream)) {
      Sheet sheet = workbook.getSheetAt(0);
      Row headerRow = sheet.getRow(sheet.getFirstRowNum());
      if (headerRow == null) return rows;
      Map<Integer, String> columnByIndex = new LinkedHashMap<>();
      for (Cell cell : headerRow) {
        String canonical = HEADER_ALIASES.get(normalize(formatter.formatCellValue(cell)));
        if (canonical != null) columnByIndex.put(cell.getColumnIndex(), canonical);
      }
      for (int r = headerRow.getRowNum() + 1; r <= sheet.getLastRowNum(); r++) {
        Row currentRow = sheet.getRow(r);
        if (currentRow == null) continue;
        Map<String, String> row = new LinkedHashMap<>();
        for (Map.Entry<Integer, String> entry : columnByIndex.entrySet()) {
          Cell cell = currentRow.getCell(entry.getKey());
          if (cell == null) continue;
          String text = cell.getCellType() == CellType.NUMERIC && !org.apache.poi.ss.usermodel.DateUtil.isCellDateFormatted(cell)
              ? formatter.formatCellValue(cell).trim()
              : formatter.formatCellValue(cell).trim();
          row.put(entry.getValue(), text);
        }
        if (row.values().stream().anyMatch(v -> v != null && !v.isBlank())) rows.add(row);
      }
    }
    return rows;
  }

  private Map<String, String> normalizeHeaders(List<String> headers) {
    Map<String, String> map = new LinkedHashMap<>();
    for (String header : headers) {
      String canonical = HEADER_ALIASES.get(normalize(header));
      if (canonical != null) map.put(header, canonical);
    }
    return map;
  }

  private String normalize(String header) {
    return header == null ? "" : header.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
  }
}

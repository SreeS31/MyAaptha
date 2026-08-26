package com.myaaptha.domain.network;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFSheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

/**
 * Builds the downloadable relationship bulk-import Excel template. Generated on demand (rather
 * than checked in as a static binary) so the columns and sample data always match
 * {@link RelationshipBulkImportService} and {@link NetworkService#relationshipTypes()}.
 */
@Service
public class RelationshipImportTemplateService {
  private static final String[] MANDATORY_COLUMNS = {"Full Name", "Relationship To You"};
  private static final String[] OPTIONAL_COLUMNS = {
      "Row Id", "Relative To (Row Id or User Id)", "Person Type (ACCOUNT/MANAGED)",
      "Managed Category (CHILD/MEMORIAL/OTHER)", "Mobile Number", "Email",
      "Date Of Birth (YYYY-MM-DD)", "Date Of Death (YYYY-MM-DD)", "Milestone Date (YYYY-MM-DD)",
      "Visibility Scope (PUBLIC/FRIENDS/RELATIVES/COLLEAGUES)", "Visibility Company", "Notes"};

  private final NetworkService networkService;

  public RelationshipImportTemplateService(NetworkService networkService) {
    this.networkService = networkService;
  }

  public byte[] build() {
    try (XSSFWorkbook workbook = new XSSFWorkbook()) {
      String[] headers = {"Row Id", "Full Name", "Relationship To You", "Relative To (Row Id or User Id)",
          "Person Type (ACCOUNT/MANAGED)", "Managed Category (CHILD/MEMORIAL/OTHER)", "Mobile Number", "Email",
          "Date Of Birth (YYYY-MM-DD)", "Date Of Death (YYYY-MM-DD)", "Milestone Date (YYYY-MM-DD)",
          "Visibility Scope (PUBLIC/FRIENDS/RELATIVES/COLLEAGUES)", "Visibility Company", "Notes"};

      XSSFSheet sheet = workbook.createSheet("Relationships");
      CellStyle mandatoryStyle = headerStyle(workbook, new byte[]{(byte) 0xF8, (byte) 0xC9, (byte) 0xC9});
      CellStyle optionalStyle = headerStyle(workbook, new byte[]{(byte) 0xC9, (byte) 0xE6, (byte) 0xF8});

      Row headerRow = sheet.createRow(0);
      for (int i = 0; i < headers.length; i++) {
        var cell = headerRow.createCell(i);
        cell.setCellValue(headers[i]);
        cell.setCellStyle(isMandatory(headers[i]) ? mandatoryStyle : optionalStyle);
        sheet.setColumnWidth(i, 26 * 256);
      }

      String[][] sampleRows = {
          {"R1", "Ravi Kumar", "Father", "", "ACCOUNT", "", "9876500001", "ravi.kumar@example.com", "1968-05-14", "", "", "FRIENDS", "", "Lives in Hyderabad"},
          {"R2", "Lakshmi Kumar", "Mother", "", "ACCOUNT", "", "9876500002", "lakshmi.kumar@example.com", "1970-02-20", "", "1990-11-30", "FRIENDS", "", "Wedding anniversary in Milestone Date"},
          {"R3", "Anjali Kumar", "Sister", "R1", "ACCOUNT", "", "9876500003", "anjali.kumar@example.com", "1995-07-09", "", "", "RELATIVES", "", "Relative To links her under Father in the tree"},
          {"R4", "Grandma Devi", "Grandmother", "R1", "MANAGED", "MEMORIAL", "", "", "1935-01-01", "2018-06-12", "", "RELATIVES", "", "MANAGED + MEMORIAL creates a memorial profile you control"},
      };
      for (int r = 0; r < sampleRows.length; r++) {
        Row row = sheet.createRow(r + 1);
        for (int c = 0; c < sampleRows[r].length; c++) {
          row.createCell(c).setCellValue(sampleRows[r][c]);
        }
      }
      sheet.createFreezePane(0, 1);

      buildInstructionsSheet(workbook);

      ByteArrayOutputStream out = new ByteArrayOutputStream();
      workbook.write(out);
      return out.toByteArray();
    } catch (IOException ex) {
      throw new IllegalStateException("Unable to build relationship import template", ex);
    }
  }

  private boolean isMandatory(String header) {
    for (String mandatory : MANDATORY_COLUMNS) {
      if (header.equals(mandatory)) return true;
    }
    return false;
  }

  private CellStyle headerStyle(XSSFWorkbook workbook, byte[] rgb) {
    XSSFCellStyle style = workbook.createCellStyle();
    style.setFillForegroundColor(new XSSFColor(rgb, null));
    style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
    style.setBorderBottom(BorderStyle.THIN);
    style.setBorderTop(BorderStyle.THIN);
    style.setBorderLeft(BorderStyle.THIN);
    style.setBorderRight(BorderStyle.THIN);
    Font font = workbook.createFont();
    font.setBold(true);
    style.setFont(font);
    return style;
  }

  private void buildInstructionsSheet(XSSFWorkbook workbook) {
    Sheet sheet = workbook.createSheet("Instructions");
    sheet.setColumnWidth(0, 40 * 256);
    sheet.setColumnWidth(1, 90 * 256);
    int r = 0;
    r = writeLine(sheet, r, "How to use this template", null, true);
    r = writeLine(sheet, r, "Red headers", "Mandatory. A row fails to import without these.");
    r = writeLine(sheet, r, "Blue headers", "Optional. Leave blank if not applicable.");
    r++;
    r = writeLine(sheet, r, "Full Name", "Mandatory. The person's full name.");
    r = writeLine(sheet, r, "Relationship To You", "Mandatory. One of: " + String.join(", ", networkService.relationshipTypes()));
    r = writeLine(sheet, r, "Row Id", "Optional short label (R1, R2, ...) so other rows in this same file can reference this person via \"Relative To\".");
    r = writeLine(sheet, r, "Relative To (Row Id or User Id)", "Optional. Anchors this person under another person already in your tree - either a Row Id from an earlier row in this file, or an existing MyAaptha user id. Leave blank to link them directly to you.");
    r = writeLine(sheet, r, "Person Type (ACCOUNT/MANAGED)", "Optional, defaults to ACCOUNT. ACCOUNT invites the person by mobile number. MANAGED creates a profile you control (for children or memorials) and needs Managed Category.");
    r = writeLine(sheet, r, "Managed Category (CHILD/MEMORIAL/OTHER)", "Required only when Person Type is MANAGED.");
    r = writeLine(sheet, r, "Mobile Number", "Required only when Person Type is ACCOUNT.");
    r = writeLine(sheet, r, "Email", "Optional.");
    r = writeLine(sheet, r, "Date Of Birth (YYYY-MM-DD)", "Optional.");
    r = writeLine(sheet, r, "Date Of Death (YYYY-MM-DD)", "Optional, memorial profiles only.");
    r = writeLine(sheet, r, "Milestone Date (YYYY-MM-DD)", "Optional, e.g. anniversary.");
    r = writeLine(sheet, r, "Visibility Scope (PUBLIC/FRIENDS/RELATIVES/COLLEAGUES)", "Optional, defaults to FRIENDS.");
    r = writeLine(sheet, r, "Visibility Company", "Optional, required only when Visibility Scope is COLLEAGUES and must match a company already saved in your employment profile.");
    r = writeLine(sheet, r, "Notes", "Optional, private notes only you can see.");
    r++;
    writeLine(sheet, r, "Tip", "Fill one row per relative. Upload up to 500 rows at once and the whole tree is created in a single shot.");
  }

  private int writeLine(Sheet sheet, int rowIndex, String label, String detail) {
    return writeLine(sheet, rowIndex, label, detail, false);
  }

  private int writeLine(Sheet sheet, int rowIndex, String label, String detail, boolean heading) {
    Row row = sheet.createRow(rowIndex);
    var labelCell = row.createCell(0);
    labelCell.setCellValue(label);
    if (heading) {
      Font font = sheet.getWorkbook().createFont();
      font.setBold(true);
      CellStyle style = sheet.getWorkbook().createCellStyle();
      style.setFont(font);
      labelCell.setCellStyle(style);
    }
    if (detail != null) row.createCell(1).setCellValue(detail);
    return rowIndex + 1;
  }
}

package com.myaaptha.domain.finance;

import java.io.*;
import java.math.BigDecimal;
import java.nio.*;
import java.nio.charset.*;
import java.time.*;
import java.time.format.*;
import java.util.*;
import java.util.regex.*;
import org.apache.commons.csv.*;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.ss.usermodel.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

/** Bounded, local extraction. It never executes spreadsheet formulas or sends statements to an AI provider. */
@Component
public class StatementParser {
 public static final int MAX_ROWS=2000,MAX_BYTES=10*1024*1024;
 public record Extracted(int line,String date,BigDecimal amount,String direction,String description,String reference,List<String> issues){}
 public record Parsed(List<Extracted> rows,List<String> warnings){}
 private static final Map<String,Set<String>> ALIASES=Map.of(
  "date",Set.of("date","transactiondate","txndate","postingdate","valuedate","transactiondatetime"),
  "description",Set.of("description","narration","particulars","transactiondetails","details","merchant","payee","remark","remarks"),
  "debit",Set.of("debit","debitamount","withdrawal","withdrawals","withdrawalamount","paidout","moneyout","dr"),
  "credit",Set.of("credit","creditamount","deposit","deposits","depositamount","paidin","moneyin","cr"),
  "amount",Set.of("amount","transactionamount","txnamount"),
  "direction",Set.of("type","direction","transactiontype","debitcredit","drcr","crdr"),
  "reference",Set.of("reference","referenceno","referenceid","transactionid","utr","chequeno","chqrefno"),
  "currency",Set.of("currency","currencycode"));
 public Parsed parse(MultipartFile file,String order,ZoneId zone){
  if(file==null||file.isEmpty()||file.getSize()>MAX_BYTES)throw bad("Choose a statement up to 10 MB");
  if(!Set.of("DMY","MDY","ISO").contains(order))throw bad("Choose a date format");
  String name=Objects.requireNonNullElse(file.getOriginalFilename(),"").toLowerCase(Locale.ROOT);
  try{
   byte[] bytes;try(var input=file.getInputStream()){bytes=input.readNBytes(MAX_BYTES+1);}if(bytes.length>MAX_BYTES)throw bad("Statement exceeds 10 MB");
   if(name.endsWith(".pdf"))return pdf(bytes,order,zone);
   List<List<String>> cells;
   if(name.endsWith(".xlsx")||name.endsWith(".xls"))cells=excel(bytes);
   else if(name.endsWith(".csv")||name.endsWith(".tsv")||name.endsWith(".txt"))cells=csv(bytes);
   else throw bad("Choose CSV, Excel or a text-based PDF statement");
   return table(cells,order,zone);
  }catch(ResponseStatusException e){throw e;}catch(org.apache.pdfbox.pdmodel.encryption.InvalidPasswordException e){throw bad("This PDF is password protected. Export an unlocked copy or CSV; do not share your bank password");}catch(Exception e){throw bad("This file could not be read. Export a CSV or Excel statement and try again");}
 }
 private List<List<String>> csv(byte[] bytes)throws Exception{
  Charset charset=bytes.length>1&&(bytes[0]==(byte)0xff&&bytes[1]==(byte)0xfe||bytes[0]==(byte)0xfe&&bytes[1]==(byte)0xff)?StandardCharsets.UTF_16:StandardCharsets.UTF_8;
  String text=charset.newDecoder().onMalformedInput(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString().replace("\uFEFF","");
  char delimiter=',';int best=0;for(char c:new char[]{',',';','\t'}){for(String line:text.lines().limit(50).toList()){Set<String> names=new HashSet<>();for(String cell:line.split(Pattern.quote(String.valueOf(c)),-1))names.add(normal(cell));boolean hasDate=names.stream().anyMatch(ALIASES.get("date")::contains),hasMoney=names.stream().anyMatch(value->ALIASES.get("amount").contains(value)||ALIASES.get("debit").contains(value)||ALIASES.get("credit").contains(value));int score=hasDate&&hasMoney?names.size():0;if(score>best){best=score;delimiter=c;}}}
  List<List<String>> rows=new ArrayList<>();try(var parsed=CSVFormat.DEFAULT.builder().setDelimiter(delimiter).setIgnoreEmptyLines(true).build().parse(new StringReader(text))){for(var row:parsed){if(rows.size()>=MAX_ROWS+51)throw bad("Split statements with more than 2,000 transaction rows");if(row.size()>100)throw bad("The statement has too many columns");List<String> values=new ArrayList<>();for(String cell:row){if(cell.length()>4000)throw bad("A statement cell is too long");values.add(cell.trim());}rows.add(values);}}return rows;
 }
 private List<List<String>> excel(byte[] bytes)throws Exception{
  List<List<String>> rows=new ArrayList<>();DataFormatter format=new DataFormatter(Locale.ROOT);
  try(Workbook book=WorkbookFactory.create(new ByteArrayInputStream(bytes))){if(book.getNumberOfSheets()!=1)throw bad("Export one statement worksheet at a time");Sheet sheet=book.getSheetAt(0);if(sheet.getLastRowNum()>MAX_ROWS+50)throw bad("Split statements with more than 2,000 transaction rows");for(Row row:sheet){if(row.getLastCellNum()>100)throw bad("The statement has too many columns");List<String> values=new ArrayList<>();for(int c=0;c<row.getLastCellNum();c++){Cell cell=row.getCell(c);String value="";if(cell!=null){if(cell.getCellType()==CellType.FORMULA)value="[formula - export values only]";else if(cell.getCellType()==CellType.NUMERIC&&DateUtil.isCellDateFormatted(cell))value=cell.getLocalDateTimeCellValue().toLocalDate().toString();else value=format.formatCellValue(cell);}if(value.length()>4000)throw bad("A statement cell is too long");values.add(value.trim());}rows.add(values);}}return rows;
 }
 private Parsed table(List<List<String>> cells,String order,ZoneId zone){
  int header=-1;Map<String,Integer> columns=new HashMap<>();for(int i=0;i<Math.min(50,cells.size());i++){Map<String,Integer> candidate=new HashMap<>();for(int j=0;j<cells.get(i).size();j++){String key=normal(cells.get(i).get(j));for(var alias:ALIASES.entrySet())if(alias.getValue().contains(key))candidate.putIfAbsent(alias.getKey(),j);}if(candidate.containsKey("date")&&(candidate.containsKey("amount")||candidate.containsKey("debit")||candidate.containsKey("credit"))){header=i;columns=candidate;break;}}
  if(header<0)throw bad("No transaction columns found. Use Date, Description and Debit/Credit, or Amount with Type (DR/CR). Balance alone is not a transaction amount");
  List<Extracted> result=new ArrayList<>();int skipped=0;
  for(int i=header+1;i<cells.size();i++){
   var row=cells.get(i);if(row.stream().allMatch(String::isBlank))continue;
   String date=value(row,columns,"date"),description=value(row,columns,"description"),reference=value(row,columns,"reference");
   if(date.isBlank()){skipped++;continue;}
   List<String> issues=new ArrayList<>();BigDecimal amount=null;String direction="";
   try{
    BigDecimal debit=amount(value(row,columns,"debit")),credit=amount(value(row,columns,"credit"));
    if(debit!=null&&debit.signum()!=0&&credit!=null&&credit.signum()!=0)throw bad("Both debit and credit have values");
    if(debit!=null&&debit.signum()!=0){amount=debit.abs();direction="EXPENSE";}else if(credit!=null&&credit.signum()!=0){amount=credit.abs();direction="INCOME";}
    else{String raw=value(row,columns,"amount"),kind=value(row,columns,"direction").toUpperCase(Locale.ROOT);amount=amount(raw);if(kind.matches("DR|DEBIT|EXPENSE|WITHDRAWAL")||raw.trim().toUpperCase(Locale.ROOT).endsWith("DR"))direction="EXPENSE";else if(kind.matches("CR|CREDIT|INCOME|DEPOSIT")||raw.trim().toUpperCase(Locale.ROOT).endsWith("CR"))direction="INCOME";else if(amount!=null&&amount.signum()<0)direction="EXPENSE";else throw bad("Choose income or expense; the statement does not specify it");if(amount!=null)amount=amount.abs();}
    validateAmount(amount);
   }catch(ResponseStatusException|NumberFormatException e){issues.add(e instanceof ResponseStatusException r?r.getReason():"Amount could not be read");}
   String currency=value(row,columns,"currency");if(!currency.isBlank()&&!currency.equalsIgnoreCase("INR")&&!currency.equals("\u20B9"))issues.add("Only INR statements are supported; currencies are never combined");
   String parsedDate=date;try{parsedDate=date(date,order,zone).toString();}catch(Exception e){issues.add("Invalid or future date: choose the correct date format");}
   if(description.length()>500||reference.length()>100)issues.add("Description or reference is too long");
   result.add(new Extracted(i+1,parsedDate,amount,direction,description,reference,issues));if(result.size()>MAX_ROWS)throw bad("Split statements with more than 2,000 transaction rows");
  }
  if(result.isEmpty())throw bad("No dated transaction rows found");
  List<String> warnings=new ArrayList<>(List.of("Review every row before saving. Categories are suggestions, not verified merchant purposes.","INR only. Opening/closing balances and undated lines are not imported."));if(skipped>0)warnings.add(skipped+" undated lines skipped; compare the preview with your statement.");return new Parsed(result,warnings);
 }
 private Parsed pdf(byte[] bytes,String order,ZoneId zone)throws Exception{
  try(var document=Loader.loadPDF(bytes)){
   if(document.getNumberOfPages()>100)throw bad("Split PDFs with more than 100 pages");if(!document.getCurrentAccessPermission().canExtractContent())throw bad("This PDF does not allow text extraction; use a bank CSV export");
   var extractor=new PDFTextStripper();extractor.setSortByPosition(true);String text=extractor.getText(document);if(text.length()>2_000_000)throw bad("Statement text is too large");
   // Explicit DR/CR beside an amount is required. A trailing running balance must never be treated as spending.
   Pattern line=Pattern.compile("^(\\d{1,4}[-/.]\\d{1,2}[-/.]\\d{2,4})\\s+(.+?)\\s+([0-9,]+\\.[0-9]{2})\\s*(DR|CR)\\b.*$",Pattern.CASE_INSENSITIVE);
   List<List<String>> rows=new ArrayList<>();rows.add(List.of("Date","Description","Amount","Type"));int candidates=0;
   for(String value:text.split("\\R")){if(value.matches("^\\d{1,4}[-/.]\\d{1,2}[-/.]\\d{2,4}\\s+.*"))candidates++;Matcher match=line.matcher(value.trim());if(match.matches())rows.add(List.of(match.group(1),match.group(2),match.group(3),match.group(4)));if(rows.size()>MAX_ROWS)throw bad("Split statements with more than 2,000 transactions");}
   if(rows.size()==1)throw bad("This PDF has no reliably readable DR/CR transaction rows. For scanned PDFs or separate debit/credit layouts, export CSV/Excel from your bank");
   Parsed parsed=table(rows,order,zone);List<String> warnings=new ArrayList<>(parsed.warnings());warnings.add("PDF extraction supports amounts explicitly labelled DR/CR. Compare every row with the original; no OCR is performed.");if(candidates>rows.size()-1)warnings.add((candidates-rows.size()+1)+" dated PDF lines could not be extracted; import the bank CSV for complete coverage.");return new Parsed(parsed.rows(),warnings);
  }
 }
 static Instant date(String value,String order,ZoneId zone){
  try{Instant at=Instant.parse(value);if(at.isAfter(Instant.now())||at.isBefore(Instant.parse("1900-01-01T00:00:00Z")))throw bad("Invalid transaction date");return at;}catch(DateTimeParseException ignored){}
  try{LocalDateTime local=LocalDateTime.parse(value,DateTimeFormatter.ISO_LOCAL_DATE_TIME);Instant at=local.atZone(zone).toInstant();if(at.isAfter(Instant.now())||local.getYear()<1900)throw bad("Invalid transaction date");return at;}catch(DateTimeParseException ignored){}
  LocalDate date=null;try{date=LocalDate.parse(value,DateTimeFormatter.ISO_LOCAL_DATE);}catch(DateTimeException ignored){}
  if(date==null)for(String pattern:List.of("d-MMM-uuuu","d MMM uuuu")){try{date=LocalDate.parse(value,new DateTimeFormatterBuilder().parseCaseInsensitive().appendPattern(pattern).toFormatter(Locale.ENGLISH).withResolverStyle(ResolverStyle.STRICT));break;}catch(DateTimeParseException ignored){}}
  if(date==null){String pattern=order.equals("MDY")?"M/d/uuuu":order.equals("DMY")?"d/M/uuuu":"uuuu/M/d";String normalized=value.replace('-','/').replace('.','/');if(!order.equals("ISO")&&normalized.matches("[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}")){var reduced=new DateTimeFormatterBuilder().appendPattern(order.equals("MDY")?"M/d/":"d/M/").appendValueReduced(java.time.temporal.ChronoField.YEAR,2,2,1970).toFormatter(Locale.ROOT).withResolverStyle(ResolverStyle.STRICT);date=LocalDate.parse(normalized,reduced);}else{date=LocalDate.parse(normalized,DateTimeFormatter.ofPattern(pattern,Locale.ROOT).withResolverStyle(ResolverStyle.STRICT));}}
  if(date.isAfter(LocalDate.now(zone))||date.getYear()<1900)throw bad("Choose a date from 1900 through today");return date.atStartOfDay(zone).toInstant();
 }
 static BigDecimal amount(String value){String s=value.trim().toUpperCase(Locale.ROOT);if(s.isEmpty()||s.equals("-")||s.equals("NIL"))return null;s=s.replace("INR","").replace("RS.","").replace("\u20B9","").replaceAll("\\s*(DR|CR)$","").trim();boolean negative=s.startsWith("(")&&s.endsWith(")");if(negative)s=s.substring(1,s.length()-1);if(!s.matches("[+-]?(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{1,2}(?:,[0-9]{2})*,[0-9]{3})(?:\\.[0-9]{1,2})?"))throw bad("Use decimal amounts with at most two decimal places");BigDecimal result=new BigDecimal(s.replace(",",""));return negative?result.negate():result;}
 static void validateAmount(BigDecimal amount){if(amount==null||amount.signum()<=0||amount.scale()>2||amount.compareTo(new BigDecimal("1000000000000"))>0)throw bad("Amount must be positive, at most 1,000,000,000,000 and have at most two decimal places");}
 static String normal(String s){return s.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]","");}
 private static String value(List<String> row,Map<String,Integer> columns,String key){Integer index=columns.get(key);return index==null||index>=row.size()?"":row.get(index).trim();}
 static ResponseStatusException bad(String message){return new ResponseStatusException(HttpStatus.BAD_REQUEST,message);}
}

package com.myaaptha.domain.finance;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.Principal;
import java.time.*;
import java.util.*;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@RestController @RequestMapping("/api/finance")
public class FinanceStatements {
 public static final List<String> CATEGORIES=List.of("GROCERIES","CLOTHING","SHOPPING","FOOD","UTILITIES","BILLS","HOUSING","TRANSPORT","TRAVEL","HEALTH","INSURANCE","EDUCATION","ENTERTAINMENT","INVESTMENT","TAX","FEES","SALARY","BUSINESS","INTEREST","REFUND","INCOME","TRANSFER","OTHER");
 public record Row(int line,@NotBlank @Size(max=64) String sourceKey,@NotNull BigDecimal amount,@NotBlank String direction,@NotBlank String category,@Size(max=160) String merchant,@Size(max=500) String description,@NotNull Instant occurredAt,boolean duplicate,boolean possibleDuplicate,List<String> issues){}
 public record Preview(List<Row> rows,List<String> warnings,String currency){}
 public record Commit(@Size(max=100) String account,@NotEmpty @Size(max=2000) List<@NotNull @Valid Row> rows){}
 public record Result(int imported,int duplicates){}
 public record Category(@NotBlank String category){}
 public record Bucket(String label,BigDecimal income,BigDecimal spending,BigDecimal net){}
 public record Report(String period,String anchor,String zone,String currency,Instant from,Instant to,BigDecimal income,BigDecimal spending,BigDecimal net,BigDecimal transfers,Map<String,BigDecimal> categories,Map<String,BigDecimal> incomeCategories,List<Bucket> timeline,List<FinanceService.Transaction> transactions){}
 private final StatementParser parser;private final FinancialTransactionRepository repo;private final JdbcTemplate db;
 public FinanceStatements(StatementParser parser,FinancialTransactionRepository repo,JdbcTemplate db){this.parser=parser;this.repo=repo;this.db=db;}
 private long user(Principal p){return Long.parseLong(p.getName());}
 @GetMapping("/categories") public List<String> categories(){return CATEGORIES;}
 @PostMapping(value="/statements/preview",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
 public Preview preview(Principal principal,@RequestPart MultipartFile file,@RequestParam(defaultValue="DMY") String dateOrder,@RequestParam(defaultValue="Asia/Kolkata") String zone,@RequestParam(defaultValue="") String account){
  long owner=user(principal);String identity=account(account);var parsed=parser.parse(file,dateOrder,zone(zone));Map<String,Integer> occurrences=new HashMap<>();List<Row> rows=new ArrayList<>();
  List<Instant> dates=parsed.rows().stream().map(row->{try{return Instant.parse(row.date());}catch(Exception e){return null;}}).filter(Objects::nonNull).sorted().toList();Set<String> recorded=new HashSet<>();if(!dates.isEmpty())for(var item:repo.findInMonth(owner,dates.getFirst().minusSeconds(86400),dates.getLast().plusSeconds(86400)))if(!"IMPORT".equals(item.getSource()))recorded.add(matchKey(item.getOccurredAt(),item.getDirection(),item.getAmount(),zone(zone)));
  for(var row:parsed.rows()){
   String canonical=row.date()+"|"+row.direction()+"|"+(row.amount()==null?"":row.amount().stripTrailingZeros().toPlainString())+"|"+(row.reference().isBlank()?row.description():row.reference()).trim().toLowerCase(Locale.ROOT).replaceAll("\\s+"," ");int ordinal=occurrences.merge(canonical,1,Integer::sum);String sourceKey=hash(canonical+"|"+ordinal);
   Instant date;try{date=Instant.parse(row.date());}catch(Exception e){date=null;}
   String category=suggest(row.description(),row.direction());boolean duplicate=repo.findByUserIdAndSourceFingerprint(owner,fingerprint(identity,sourceKey)).isPresent();rows.add(new Row(row.line(),sourceKey,row.amount(),row.direction(),category,row.description().substring(0,Math.min(160,row.description().length())),row.description(),date,duplicate,date!=null&&row.amount()!=null&&recorded.contains(matchKey(date,row.direction(),row.amount(),zone(zone))),row.issues()));
  }
  return new Preview(rows,parsed.warnings(),"INR");
 }
 @PostMapping("/statements/commit") @Transactional
 public Result commit(Principal principal,@Valid @RequestBody Commit request){
  long owner=user(principal);String identity=account(request.account());db.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,owner);int added=0,duplicates=0;
  for(Row row:request.rows()){
   validate(row);String key=fingerprint(identity,row.sourceKey());if(repo.findByUserIdAndSourceFingerprint(owner,key).isPresent()){duplicates++;continue;}
   var entity=new FinancialTransactionEntity();entity.setUserId(owner);entity.setAmount(row.amount().setScale(2));entity.setDirection(row.direction());entity.setCategory(row.category());entity.setMerchant(row.merchant());entity.setDescription(row.description());entity.setOccurredAt(row.occurredAt());entity.setSource("IMPORT");entity.setSourceFingerprint(key);repo.save(entity);added++;
  }
  return new Result(added,duplicates);
 }
 @PostMapping("/transactions/{id}/category") @Transactional
 public void category(Principal principal,@PathVariable long id,@Valid @RequestBody Category input){if(!CATEGORIES.contains(input.category()))throw StatementParser.bad("Choose a valid category");var row=repo.findById(id).filter(r->r.getUserId().equals(user(principal))).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND));row.setCategory(input.category());repo.save(row);}
 @GetMapping("/reports") public Report report(Principal principal,@RequestParam(defaultValue="MONTH") String period,@RequestParam String anchor,@RequestParam(defaultValue="Asia/Kolkata") String zone){
  YearMonth month;try{if(!anchor.matches("(?!0000)[0-9]{4}-(0[1-9]|1[0-2])"))throw new IllegalArgumentException();month=YearMonth.parse(anchor);}catch(Exception e){throw StatementParser.bad("Choose an anchor month in YYYY-MM format");}
  if(!Set.of("MONTH","QUARTER","YEAR").contains(period))throw StatementParser.bad("Choose month, quarter or year");ZoneId timezone=zone(zone);YearMonth start=period.equals("YEAR")?YearMonth.of(month.getYear(),1):period.equals("QUARTER")?YearMonth.of(month.getYear(),((month.getMonthValue()-1)/3)*3+1):month;int count=period.equals("YEAR")?12:period.equals("QUARTER")?3:1;
  Instant from=start.atDay(1).atStartOfDay(timezone).toInstant(),to=start.plusMonths(count).atDay(1).atStartOfDay(timezone).toInstant();List<FinanceService.Transaction> transactions=repo.findInMonth(user(principal),from,to).stream().map(FinanceStatements::dto).toList();BigDecimal income=sum(transactions,"INCOME"),spending=sum(transactions,"EXPENSE"),transfers=transactions.stream().filter(t->t.category().equals("TRANSFER")).map(FinanceService.Transaction::amount).reduce(BigDecimal.ZERO,BigDecimal::add);Map<String,BigDecimal> expenses=new LinkedHashMap<>(),sources=new LinkedHashMap<>();
  for(var row:transactions)if(!row.category().equals("TRANSFER"))(row.direction().equals("INCOME")?sources:expenses).merge(row.category(),row.amount(),BigDecimal::add);
  List<Bucket> timeline=new ArrayList<>();for(int i=0;i<count;i++){YearMonth target=start.plusMonths(i);var subset=transactions.stream().filter(t->YearMonth.from(t.occurredAt().atZone(timezone)).equals(target)).toList();BigDecimal incoming=sum(subset,"INCOME"),outgoing=sum(subset,"EXPENSE");timeline.add(new Bucket(target.toString(),incoming,outgoing,incoming.subtract(outgoing)));}
  return new Report(period,anchor,timezone.getId(),"INR",from,to,income,spending,income.subtract(spending),transfers,expenses,sources,timeline,transactions);
 }
 @GetMapping("/reports/export") public ResponseEntity<byte[]> export(Principal principal,@RequestParam(defaultValue="MONTH") String period,@RequestParam String anchor,@RequestParam(defaultValue="Asia/Kolkata") String zone){var report=report(principal,period,anchor,zone);StringBuilder csv=new StringBuilder("Date,Description,Merchant,Type,Category,Amount,Currency,Source\r\n");for(var row:report.transactions()){csv.append(quoted(row.occurredAt().atZone(zone(zone)).toLocalDate().toString())).append(',').append(quoted(row.description())).append(',').append(quoted(row.merchant())).append(',').append(quoted(row.direction())).append(',').append(quoted(row.category())).append(',').append(row.amount().toPlainString()).append(",INR,").append(quoted(row.source())).append("\r\n");}return ResponseEntity.ok().contentType(MediaType.parseMediaType("text/csv;charset=UTF-8")).header(HttpHeaders.CACHE_CONTROL,"no-store").header(HttpHeaders.CONTENT_DISPOSITION,"attachment; filename=\"myaaptha-"+period.toLowerCase(Locale.ROOT)+"-"+anchor+".csv\"").body(csv.toString().getBytes(StandardCharsets.UTF_8));}
 private static FinanceService.Transaction dto(FinancialTransactionEntity e){return new FinanceService.Transaction(e.getId(),e.getAmount(),e.getDirection(),e.getCategory(),e.getMerchant(),e.getDescription(),e.getOccurredAt(),e.getSource());}
 private static BigDecimal sum(List<FinanceService.Transaction> rows,String direction){return rows.stream().filter(t->t.direction().equals(direction)&&!t.category().equals("TRANSFER")).map(FinanceService.Transaction::amount).reduce(BigDecimal.ZERO,BigDecimal::add);}
 private static void validate(Row row){StatementParser.validateAmount(row.amount());if(!row.sourceKey().matches("[a-f0-9]{64}")||!Set.of("INCOME","EXPENSE").contains(row.direction())||!CATEGORIES.contains(row.category())||row.occurredAt().isAfter(Instant.now())||row.occurredAt().isBefore(Instant.parse("1900-01-01T00:00:00Z")))throw StatementParser.bad("Review the transaction date, type and category before saving");}
 static String suggest(String description,String direction){String s=description.toLowerCase(Locale.ROOT);if(s.matches(".*(self transfer|own account|credit card payment|card bill payment).*"))return "TRANSFER";if(direction.equals("INCOME")){if(s.matches(".*(salary|payroll|wages).*"))return "SALARY";if(s.contains("refund")||s.contains("reversal"))return "REFUND";if(s.contains("interest"))return "INTEREST";return "INCOME";}for(var rule:List.of(new String[]{"GROCERIES","grocery|groceries|supermarket|vegetable|bigbasket|blinkit|zepto|dmart|d-mart"},new String[]{"CLOTHING","cloth|apparel|myntra|ajio|zara|fashion"},new String[]{"HEALTH","hospital|pharmacy|medical|doctor|clinic|apollo"},new String[]{"INSURANCE","insurance|premium"},new String[]{"FOOD","restaurant|swiggy|zomato|cafe|food"},new String[]{"UTILITIES","electricity|broadband|utility|recharge|water bill|gas bill|mobile bill"},new String[]{"HOUSING","rent|maintenance|housing"},new String[]{"TRANSPORT","uber|ola|fuel|petrol|metro|diesel"},new String[]{"TRAVEL","hotel|flight|airline|irctc|travel"},new String[]{"EDUCATION","school|tuition|college|course|education"},new String[]{"INVESTMENT","mutual fund|sip|demat|investment"},new String[]{"TAX","income tax|gst|tax payment"},new String[]{"FEES","bank charge|service charge|processing fee|annual fee"},new String[]{"ENTERTAINMENT","netflix|spotify|cinema|movie"},new String[]{"BILLS","bill payment|billpay"},new String[]{"SHOPPING","amazon|flipkart|mall|shopping"}))if(s.matches(".*("+rule[1]+").*"))return rule[0];return "OTHER";}
 private static ZoneId zone(String zone){try{return ZoneId.of(zone);}catch(Exception e){throw StatementParser.bad("Choose a valid report timezone");}}
 private static String account(String account){String value=account==null?"":account.trim().toLowerCase(Locale.ROOT);if(value.length()>100)throw StatementParser.bad("Account label must be at most 100 characters");return value;}
 private static String matchKey(Instant date,String direction,BigDecimal amount,ZoneId zone){return date.atZone(zone).toLocalDate()+"|"+direction+"|"+amount.stripTrailingZeros().toPlainString();}
 private static String fingerprint(String account,String key){return hash("statement-v1|"+account+"|"+key);}
 private static String hash(String text){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}
 static String quoted(String text){String value=Objects.requireNonNullElse(text,"");if(value.stripLeading().matches("(?s)^[=+@\\-].*"))value="'"+value;return '"'+value.replace("\"","\"\"")+'"';}
}

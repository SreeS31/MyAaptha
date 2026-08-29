package com.myaaptha.domain.health;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.*;
import java.time.Duration;
import java.time.LocalDate;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class HealthReportAnalyzer {
 private static final Set<String> TYPES=Set.of("application/pdf","image/jpeg","image/png");
 private final ObjectMapper json; private final HttpClient http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(20)).build();
 @Value("${myaaptha.health-ai.api-key:}") String key;
 @Value("${myaaptha.health-ai.model:gpt-4.1-mini}") String model;
 public HealthReportAnalyzer(ObjectMapper json){this.json=json;}
 public HealthService.ReportInput analyze(MultipartFile file){
  if(file==null||file.isEmpty())bad(HttpStatus.BAD_REQUEST,"Choose a non-empty PDF, JPEG or PNG report");
  String mime=file.getContentType();
  if(!TYPES.contains(mime))bad(HttpStatus.BAD_REQUEST,"Only PDF, JPEG and PNG reports are supported");
  if(key==null||key.isBlank())bad(HttpStatus.SERVICE_UNAVAILABLE,"AI report analysis is not configured");
  try{
   String data="data:"+mime+";base64,"+Base64.getEncoder().encodeToString(file.getBytes());
   Map<String,Object> document=mime.startsWith("image/")?Map.of("type","input_image","image_url",data,"detail","high"):Map.of("type","input_file","filename",safe(file.getOriginalFilename()),"file_data",data);
   Map<String,Object> payload=Map.of("model",model,"input",new Object[]{Map.of("role","user","content",new Object[]{Map.of("type","input_text","text",instructions()),document})},"text",Map.of("format",Map.of("type","json_schema","name","diagnostic_report","strict",true,"schema",schema())));
   HttpRequest request=HttpRequest.newBuilder(URI.create("https://api.openai.com/v1/responses")).timeout(Duration.ofMinutes(2)).header("Authorization","Bearer "+key).header("Content-Type","application/json").POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(payload))).build();
   HttpResponse<String> response=http.send(request,HttpResponse.BodyHandlers.ofString());
   if(response.statusCode()/100!=2)bad(HttpStatus.BAD_GATEWAY,"AI could not analyze this report");
   JsonNode root=json.readTree(response.body());
   for(JsonNode output:root.path("output"))for(JsonNode content:output.path("content"))if("output_text".equals(content.path("type").asText()))return input(json.readTree(content.path("text").asText()),file.getOriginalFilename());
   bad(HttpStatus.UNPROCESSABLE_ENTITY,"No structured laboratory results were found");
  }catch(ResponseStatusException e){throw e;}catch(Exception e){bad(HttpStatus.BAD_GATEWAY,"The report could not be analyzed. Try a clearer file");}
  throw new IllegalStateException();
 }
 private HealthService.ReportInput input(JsonNode node,String filename){
  List<HealthService.MeasurementInput> values=new ArrayList<>();
  for(JsonNode item:node.path("measurements"))if(item.hasNonNull("metricName")&&item.hasNonNull("value"))values.add(new HealthService.MeasurementInput(item.path("metricName").asText(),item.path("value").decimalValue(),nullable(item,"unit","unitless"),number(item,"referenceMin"),number(item,"referenceMax"),nullable(item,"suggestion",null)));
  if(values.isEmpty())bad(HttpStatus.UNPROCESSABLE_ENTITY,"No numeric laboratory results were found");
  LocalDate date;try{date=LocalDate.parse(node.path("collectedOn").asText());}catch(Exception e){date=LocalDate.now();}
  return new HealthService.ReportInput(null,nullable(node,"reportName",base(filename)),nullable(node,"laboratory",null),date,nullable(node,"summary","AI-extracted results. Review the original report with a healthcare professional."),values);
 }
 private Map<String,Object> schema(){Map<String,Object> ns=Map.of("type",new String[]{"string","null"}),nn=Map.of("type",new String[]{"number","null"});Map<String,Object> item=Map.of("type","object","additionalProperties",false,"required",new String[]{"metricName","value","unit","referenceMin","referenceMax","suggestion"},"properties",Map.of("metricName",Map.of("type","string"),"value",Map.of("type","number"),"unit",ns,"referenceMin",nn,"referenceMax",nn,"suggestion",ns));return Map.of("type","object","additionalProperties",false,"required",new String[]{"reportName","laboratory","collectedOn","summary","measurements"},"properties",Map.of("reportName",Map.of("type","string"),"laboratory",ns,"collectedOn",Map.of("type","string","format","date"),"summary",Map.of("type","string"),"measurements",Map.of("type","array","items",item)));}
 private String instructions(){return "Extract every numeric result from every page of this diagnostic report. Include every component of panels such as lipid profile and CBC/CBP. Preserve printed units, report collection date, laboratory, and patient-specific reference ranges. Do not invent unreadable values. For each value outside its printed range, provide one brief cautious lifestyle suggestion; otherwise suggestion must be null. Never diagnose or prescribe. The summary must say the extraction is informational and requires review with a healthcare professional.";}
 private static BigDecimal number(JsonNode n,String k){return n.hasNonNull(k)?n.path(k).decimalValue():null;}private static String nullable(JsonNode n,String k,String d){return n.hasNonNull(k)?n.path(k).asText():d;}private static String safe(String n){return n==null?"health-report":n.replaceAll("[^a-zA-Z0-9._-]","_");}private static String base(String n){if(n==null||n.isBlank())return"Diagnostic report";return n.replaceFirst("\\.[^.]+$","");}private static void bad(HttpStatus s,String m){throw new ResponseStatusException(s,m);}
}

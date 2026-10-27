package com.myaaptha.domain.health;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.server.ResponseStatusException;

class HealthAnalysisConsentTest {
 @Test void keyAloneCannotEnableProcessing(){
   var analyzer=new HealthReportAnalyzer(new ObjectMapper());analyzer.key="synthetic-not-a-real-key";
   assertThat(analyzer.configured()).isFalse();
   assertThatThrownBy(()->analyzer.analyze(null,true)).isInstanceOfSatisfying(ResponseStatusException.class,e->assertThat(e.getStatusCode().value()).isEqualTo(503));
 }
 @Test void enabledWithoutKeyRemainsUnavailable(){
   var analyzer=new HealthReportAnalyzer(new ObjectMapper());analyzer.enabled=true;
   assertThat(analyzer.configured()).isFalse();
   assertThatThrownBy(()->analyzer.analyze(null,true)).isInstanceOfSatisfying(ResponseStatusException.class,e->assertThat(e.getStatusCode().value()).isEqualTo(503));
 }
 @Test void missingConsentRejectsBeforeReadingAnyFileOrCallingProvider()throws Exception{
   var analyzer=new HealthReportAnalyzer(new ObjectMapper());analyzer.enabled=true;analyzer.key="synthetic-not-a-real-key";
   var file=mock(org.springframework.web.multipart.MultipartFile.class);
   assertThat(analyzer.configured()).isTrue();
   assertThatThrownBy(()->analyzer.analyze(file,false)).isInstanceOfSatisfying(ResponseStatusException.class,e->assertThat(e.getStatusCode().value()).isEqualTo(400));
   verifyNoInteractions(file);
 }
 @Test void consentDoesNotBypassFileValidation(){
   var analyzer=new HealthReportAnalyzer(new ObjectMapper());analyzer.enabled=true;analyzer.key="synthetic-not-a-real-key";
   var file=new MockMultipartFile("file","fixture.txt","text/plain",new byte[]{1});
   assertThatThrownBy(()->analyzer.analyze(file,true)).isInstanceOfSatisfying(ResponseStatusException.class,e->assertThat(e.getStatusCode().value()).isEqualTo(400));
 }
}

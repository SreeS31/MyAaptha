package com.myaaptha.platform.media;
import static org.assertj.core.api.Assertions.*;
import java.net.*;import java.io.*;import java.time.*;import java.time.format.DateTimeFormatter;import java.util.Locale;import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;
class ClamAvMediaScannerTest {
 void scan(String result,boolean stale)throws Exception{
  try(var server=new ServerSocket(0);var executor=Executors.newSingleThreadExecutor()){
   var future=executor.submit(()->{try{
    try(var socket=server.accept()){while(socket.getInputStream().read()!=0){}String date=LocalDateTime.now(ZoneOffset.UTC).minusDays(stale?5:0).format(DateTimeFormatter.ofPattern("EEE MMM d HH:mm:ss yyyy",Locale.US));socket.getOutputStream().write(("ClamAV test/1/"+date+"\0").getBytes());}
    if(!stale)try(var socket=server.accept()){var input=new DataInputStream(socket.getInputStream());while(input.read()!=0){}int size;while((size=input.readInt())>0)input.readNBytes(size);socket.getOutputStream().write((result+"\0").getBytes());}
   }catch(IOException error){throw new UncheckedIOException(error);}});
   var scanner=new ClamAvMediaScanner(new BasicMediaScanner(),"127.0.0.1",server.getLocalPort(),48);
   try{scanner.assertClean("ordinary text".getBytes(),"notes.txt","text/plain");}finally{future.get(5,TimeUnit.SECONDS);}
  }
 }
 @Test void cleanResponsePasses()throws Exception{scan("stream: OK",false);}
 @Test void positiveDetectionIsDistinctFromValidationFailure(){assertThatThrownBy(()->scan("stream: Test-Signature FOUND",false)).isInstanceOf(UnsafeUploadException.class);}
 @Test void errorsAndStaleSignaturesFailClosed(){assertThatThrownBy(()->scan("stream: scan failed ERROR",false)).isInstanceOf(ResponseStatusException.class).satisfies(e->assertThat(((ResponseStatusException)e).getStatusCode().value()).isEqualTo(503));assertThatThrownBy(()->scan("",true)).isInstanceOf(ResponseStatusException.class).satisfies(e->assertThat(((ResponseStatusException)e).getStatusCode().value()).isEqualTo(503));}
}

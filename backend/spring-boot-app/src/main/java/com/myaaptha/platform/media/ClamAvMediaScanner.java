package com.myaaptha.platform.media;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** No object is stored or served until both validation and antivirus scanning pass. */
@Component @Primary @ConditionalOnProperty(name="myaaptha.storage.scanner",havingValue="clamav")
public class ClamAvMediaScanner implements MediaScanner {
  private final BasicMediaScanner basic;private final String host;private final int port;private final long maxAgeHours;
  public ClamAvMediaScanner(BasicMediaScanner basic,@Value("${CLAMAV_HOST:clamav}") String host,@Value("${CLAMAV_PORT:3310}") int port,@Value("${CLAMAV_MAX_SIGNATURE_AGE_HOURS:48}") long hours){this.basic=basic;this.host=host;this.port=port;this.maxAgeHours=hours;}
  private Socket connect()throws IOException{var socket=new Socket();try{socket.connect(new InetSocketAddress(host,port),2000);socket.setSoTimeout(15000);return socket;}catch(IOException error){socket.close();throw error;}}
  public void assertClean(byte[] bytes,String name,String type){
    basic.assertClean(bytes,name,type);
    try{assertFresh();try(var socket=connect();var output=new DataOutputStream(socket.getOutputStream())){
      output.write("zINSTREAM\0".getBytes(StandardCharsets.US_ASCII));
      for(int offset=0;offset<bytes.length;offset+=65536){int length=Math.min(65536,bytes.length-offset);output.writeInt(length);output.write(bytes,offset,length);}output.writeInt(0);output.flush();
      String result=reply(socket.getInputStream());
      if(result.endsWith(" FOUND"))throw new UnsafeUploadException();
      if(!result.equals("stream: OK"))throw new IOException("Scanner did not approve the file");
    }}catch(IOException|java.time.DateTimeException error){throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"File security scanning is unavailable; please retry later");}
  }
  public void assertFresh()throws IOException{
    try(var socket=connect()){
      socket.getOutputStream().write("zVERSION\0".getBytes(StandardCharsets.US_ASCII));socket.getOutputStream().flush();
      String version=reply(socket.getInputStream());String[] parts=version.split("/");if(parts.length<3)throw new IOException("Signature version unavailable");
      Instant timestamp=LocalDateTime.parse(parts[2].trim().replaceAll("\\s+"," "),DateTimeFormatter.ofPattern("EEE MMM d HH:mm:ss yyyy",Locale.US)).toInstant(ZoneOffset.UTC);
      if(timestamp.isBefore(Instant.now().minus(Duration.ofHours(maxAgeHours)))||timestamp.isAfter(Instant.now().plus(Duration.ofHours(1))))throw new IOException("Antivirus signatures are stale");
    }
  }
  private String reply(InputStream input)throws IOException{var bytes=new ByteArrayOutputStream();for(int i=0;i<4096;i++){int value=input.read();if(value==-1||value==0||value==10)return bytes.toString(StandardCharsets.UTF_8).trim();bytes.write(value);}throw new IOException("Invalid scanner response");}
}

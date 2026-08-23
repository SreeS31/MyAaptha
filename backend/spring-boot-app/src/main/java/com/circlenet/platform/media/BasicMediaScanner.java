package com.circlenet.platform.media;

import java.nio.charset.StandardCharsets;
import java.io.ByteArrayInputStream;
import java.util.Locale;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class BasicMediaScanner implements MediaScanner {
  public void assertClean(byte[] bytes,String name,String type){
    String sample=new String(bytes,0,Math.min(bytes.length,8192),StandardCharsets.ISO_8859_1);
    String lower=sample.toLowerCase(Locale.ROOT);
    if(sample.contains("EICAR-STANDARD-ANTIVIRUS-TEST-FILE")||starts(bytes,0x4d,0x5a)||starts(bytes,0x7f,0x45,0x4c,0x46)||starts(bytes,0xca,0xfe,0xba,0xbe)||starts(bytes,0xfe,0xed,0xfa,0xce)||lower.startsWith("#!")||lower.contains("<?php")||lower.contains("<script")||lower.contains("javascript:")||lower.contains("<!entity")||lower.matches("(?s).*on(load|error|click)\\s*=.*"))reject();
    if(starts(bytes,0x50,0x4b,0x03,0x04))scanArchive(bytes);
  }
  private void scanArchive(byte[] bytes){try(var input=new ZipInputStream(new ByteArrayInputStream(bytes))){int entries=0;long expanded=0;ZipEntry entry;byte[] buffer=new byte[8192];while((entry=input.getNextEntry())!=null){if(++entries>10000||entry.getName().contains("..")||entry.getName().startsWith("/")||entry.getName().startsWith("\\"))reject();int read;while((read=input.read(buffer))>0){expanded+=read;if(expanded>250L*1024*1024||expanded>Math.max(10L*1024*1024,bytes.length*100L))reject();}}}catch(ResponseStatusException exception){throw exception;}catch(Exception exception){reject();}}
  private void reject(){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"The file was rejected by the security scan");}
  private boolean starts(byte[] bytes,int... signature){if(bytes.length<signature.length)return false;for(int i=0;i<signature.length;i++)if((bytes[i]&255)!=signature[i])return false;return true;}
}

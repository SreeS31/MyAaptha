package com.myaaptha.domain.message;

import java.io.*;
import java.nio.file.Files;
import org.springframework.web.multipart.MultipartFile;

/** A bounded server-side copy; normal media validation, scanning and quotas still apply. */
public record ForwardedAttachment(String filename,String contentType,byte[] bytes) implements MultipartFile {
  public String getName(){return "file";}
  public String getOriginalFilename(){return filename;}
  public String getContentType(){return contentType;}
  public boolean isEmpty(){return bytes.length==0;}
  public long getSize(){return bytes.length;}
  public byte[] getBytes(){return bytes;}
  public InputStream getInputStream(){return new ByteArrayInputStream(bytes);}
  public void transferTo(File destination) throws IOException {Files.write(destination.toPath(),bytes);}
}

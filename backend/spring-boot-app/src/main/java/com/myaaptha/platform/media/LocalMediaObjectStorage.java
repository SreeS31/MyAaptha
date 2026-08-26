package com.myaaptha.platform.media;

import java.io.IOException;
import java.net.URI;
import java.nio.file.*;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
@ConditionalOnProperty(name="myaaptha.storage.provider",havingValue="local",matchIfMissing=true)
public class LocalMediaObjectStorage implements MediaObjectStorage {
  private final Path root;
  public LocalMediaObjectStorage(@Value("${myaaptha.storage.local-directory:./var/myaaptha/uploads}") String directory){root=Paths.get(directory).toAbsolutePath().normalize();try{Files.createDirectories(root);}catch(IOException e){throw new IllegalStateException("Cannot create media directory",e);}}
  public void put(String key,byte[] bytes,String contentType,String originalName){Path target=path(key);try{Files.createDirectories(target.getParent());Files.write(target,bytes,StandardOpenOption.CREATE_NEW);}catch(IOException e){throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,"Media upload failed");}}
  public Resource load(String key){try{Resource resource=new UrlResource(path(key).toUri());if(!resource.exists())throw new IOException();return resource;}catch(Exception e){throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Media not found");}}
  public void delete(String key){try{Files.deleteIfExists(path(key));}catch(IOException ignored){}}
  public URI signedGetUrl(String key,Duration validity){return path(key).toUri();}
  private Path path(String key){Path target=root.resolve(key).normalize();if(!target.startsWith(root))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid media key");return target;}
}

package com.myaaptha.platform.media;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
/** A positive malware/executable signature, not an unsupported extension. */
public class UnsafeUploadException extends ResponseStatusException {
 public UnsafeUploadException(){super(HttpStatus.BAD_REQUEST,"Unsafe file detected. The upload was rejected.");}
}

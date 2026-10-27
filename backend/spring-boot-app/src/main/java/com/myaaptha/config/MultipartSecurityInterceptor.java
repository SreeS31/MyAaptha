package com.myaaptha.config;

import com.myaaptha.platform.media.MediaScanner;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.multipart.MultipartHttpServletRequest;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class MultipartSecurityInterceptor implements HandlerInterceptor {
  private final MediaScanner scanner;
  private final com.myaaptha.platform.security.SecurityIncidentService incidents;
  private final java.util.concurrent.Semaphore slots=new java.util.concurrent.Semaphore(2);

  public MultipartSecurityInterceptor(MediaScanner scanner,com.myaaptha.platform.security.SecurityIncidentService incidents) { this.scanner = scanner; this.incidents=incidents; }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
    var multipart=org.springframework.web.util.WebUtils.getNativeRequest(request,MultipartHttpServletRequest.class);
    if (multipart != null) {
      if(!slots.tryAcquire())throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS,"Upload scanning is busy. Please retry shortly.");
      try {
      int count = 0;
      for (var files : multipart.getMultiFileMap().values()) {
        for (MultipartFile file : files) {
          if (++count > 10) throw new IllegalArgumentException("A request may contain at most 10 files");
          scanner.assertClean(file.getBytes(), file.getOriginalFilename(), file.getContentType());
        }
      }
      }catch(com.myaaptha.platform.media.UnsafeUploadException error){incidents.record("MALWARE","Confirmed unsafe file rejected; IP blocked for one hour",true);throw error;}
      catch(org.springframework.web.server.ResponseStatusException error){incidents.record(error.getStatusCode().value()==503?"SCANNER_UNAVAILABLE":"UPLOAD_REJECTED",error.getStatusCode().value()==503?"Antivirus unavailable; file not saved":"Upload did not meet file security policy",false);throw error;}
      finally{slots.release();}
    }
    return true;
  }
}

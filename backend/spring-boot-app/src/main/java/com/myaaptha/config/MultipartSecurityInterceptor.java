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

  public MultipartSecurityInterceptor(MediaScanner scanner) { this.scanner = scanner; }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
    if (request instanceof MultipartHttpServletRequest multipart) {
      int count = 0;
      for (var files : multipart.getMultiFileMap().values()) {
        for (MultipartFile file : files) {
          if (++count > 10) throw new IllegalArgumentException("A request may contain at most 10 files");
          scanner.assertClean(file.getBytes(), file.getOriginalFilename(), file.getContentType());
        }
      }
    }
    return true;
  }
}

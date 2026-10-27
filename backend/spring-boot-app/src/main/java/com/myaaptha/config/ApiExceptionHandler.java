package com.myaaptha.config;

import java.util.Map;
import java.util.stream.Collectors;

import jakarta.validation.ConstraintViolationException;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.BindException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
public class ApiExceptionHandler {
  @ExceptionHandler(ResponseStatusException.class)
  public ResponseEntity<Map<String, String>> handleResponseStatus(ResponseStatusException exception) {
    String message = exception.getReason() == null ? "Request failed" : exception.getReason();
    return ResponseEntity.status(exception.getStatusCode()).body(Map.of("message", message));
  }

  @ExceptionHandler({MethodArgumentNotValidException.class, BindException.class})
  public ResponseEntity<Map<String, String>> handleBinding(BindException exception) {
    String message = exception.getBindingResult().getFieldErrors().stream()
        .map(error -> error.getField() + ": " + (error.getDefaultMessage() == null ? "invalid value" : error.getDefaultMessage()))
        .distinct().collect(Collectors.joining("; "));
    return badRequest(message.isBlank() ? "Request validation failed" : message);
  }

  @ExceptionHandler(ConstraintViolationException.class)
  public ResponseEntity<Map<String, String>> handleConstraintViolation(ConstraintViolationException exception) {
    String message = exception.getConstraintViolations().stream()
        .map(violation -> violation.getPropertyPath() + ": " + violation.getMessage())
        .distinct().collect(Collectors.joining("; "));
    return badRequest(message.isBlank() ? "Request validation failed" : message);
  }

  @ExceptionHandler(HttpMessageNotReadableException.class)
  public ResponseEntity<Map<String, String>> handleUnreadableBody(HttpMessageNotReadableException exception) {
    for(Throwable cause=exception;cause!=null;cause=cause.getCause())if(cause instanceof JsonBodyLimitFilter.BodyTooLargeException)
      return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).body(Map.of("message","JSON request exceeds the size limit"));
    return badRequest("Malformed JSON or unsupported request field");
  }

  @ExceptionHandler({MissingServletRequestParameterException.class, MethodArgumentTypeMismatchException.class})
  public ResponseEntity<Map<String, String>> handleInvalidParameter(Exception exception) {
    return badRequest("A required request parameter is missing or invalid");
  }

  @ExceptionHandler(MaxUploadSizeExceededException.class)
  public ResponseEntity<Map<String, String>> handleLargeUpload() {
    return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).body(Map.of("message", "Upload exceeds the 25 MB limit"));
  }

  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<Map<String, String>> handleIllegalArgument(IllegalArgumentException exception) {
    return badRequest(exception.getMessage() == null ? "The request is invalid" : exception.getMessage());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<Map<String,String>> handleUnexpected(Exception error){
    if(error instanceof org.springframework.web.ErrorResponse response)return ResponseEntity.status(response.getStatusCode()).body(Map.of("message","Request could not be completed"));
    if(error instanceof org.springframework.security.access.AccessDeniedException)return ResponseEntity.status(403).body(Map.of("message","Access denied"));
    org.slf4j.LoggerFactory.getLogger(getClass()).error("Unhandled API exception: {}",error.getClass().getSimpleName());
    return ResponseEntity.status(500).body(Map.of("message","An unexpected server error occurred. Please try again."));
  }

  private ResponseEntity<Map<String, String>> badRequest(String message) {
    return ResponseEntity.badRequest().body(Map.of("message", message));
  }
}

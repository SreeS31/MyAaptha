package com.myaaptha.config;

import java.lang.reflect.Type;

import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Validator;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.core.MethodParameter;
import org.springframework.http.HttpInputMessage;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;
import org.springframework.web.servlet.mvc.method.annotation.RequestBodyAdviceAdapter;

@ControllerAdvice
public class ApiValidationAdvice extends RequestBodyAdviceAdapter implements HandlerInterceptor {
  private final ApiInputValidator inputValidator;
  private final Validator beanValidator;

  public ApiValidationAdvice(ApiInputValidator inputValidator, Validator beanValidator) {
    this.inputValidator = inputValidator;
    this.beanValidator = beanValidator;
  }

  @Override
  public boolean supports(MethodParameter methodParameter, Type targetType,
      Class<? extends HttpMessageConverter<?>> converterType) {
    return true;
  }

  @Override
  public Object afterBodyRead(Object body, HttpInputMessage inputMessage, MethodParameter parameter,
      Type targetType, Class<? extends HttpMessageConverter<?>> converterType) {
    inputValidator.validateBody(body);
    var violations = beanValidator.validate(body);
    if (!violations.isEmpty()) throw new ConstraintViolationException(violations);
    return body;
  }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    if (request.getRequestURI().length() > 8_192) {
      throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.URI_TOO_LONG,
          "Request URI is too long");
    }
    if (request.getParameterMap().size() > 100) {
      throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST,
          "Too many request parameters");
    }
    request.getParameterMap().forEach((name, values) -> {
      if (values.length > 100) {
        throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST,
            name + " has too many values");
      }
      for (String value : values) inputValidator.validateParameter(name, value);
    });
    Object pathVariables = request.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE);
    if (pathVariables instanceof java.util.Map<?, ?> values) {
      values.forEach((name, value) -> inputValidator.validateParameter(String.valueOf(name), String.valueOf(value)));
    }
    return true;
  }
}

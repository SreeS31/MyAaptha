package com.myaaptha.config;
import com.myaaptha.platform.audit.AuditInterceptor; import org.springframework.context.annotation.Configuration; import org.springframework.web.servlet.config.annotation.*;
@Configuration public class WebMvcConfig implements WebMvcConfigurer{private final AuditInterceptor audit;public WebMvcConfig(AuditInterceptor audit){this.audit=audit;}@Override public void addInterceptors(InterceptorRegistry registry){registry.addInterceptor(audit).addPathPatterns("/api/**");}}

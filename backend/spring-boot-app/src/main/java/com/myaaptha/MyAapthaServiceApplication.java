package com.myaaptha;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class MyAapthaServiceApplication {
  public static void main(String[] args) {
    SpringApplication.run(MyAapthaServiceApplication.class, args);
  }
}

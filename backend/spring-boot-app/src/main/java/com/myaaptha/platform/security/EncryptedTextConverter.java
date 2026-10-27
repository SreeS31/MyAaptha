package com.myaaptha.platform.security;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import org.springframework.stereotype.Component;

@Component
@Converter
public class EncryptedTextConverter implements AttributeConverter<String, String> {
  private final FieldEncryption encryption;
  public EncryptedTextConverter(FieldEncryption encryption) { this.encryption = encryption; }
  public String convertToDatabaseColumn(String value) { return encryption.encrypt(value); }
  public String convertToEntityAttribute(String value) { return encryption.decrypt(value); }
}

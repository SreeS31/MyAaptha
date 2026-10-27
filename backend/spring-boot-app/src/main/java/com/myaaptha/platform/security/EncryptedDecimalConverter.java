package com.myaaptha.platform.security;

import java.math.BigDecimal;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import org.springframework.stereotype.Component;

@Component
@Converter
public class EncryptedDecimalConverter implements AttributeConverter<BigDecimal, String> {
  private final FieldEncryption encryption;
  public EncryptedDecimalConverter(FieldEncryption encryption) { this.encryption = encryption; }
  public String convertToDatabaseColumn(BigDecimal value) { return encryption.encrypt(value == null ? null : value.toPlainString()); }
  public BigDecimal convertToEntityAttribute(String value) { return value == null ? null : new BigDecimal(encryption.decrypt(value)); }
}

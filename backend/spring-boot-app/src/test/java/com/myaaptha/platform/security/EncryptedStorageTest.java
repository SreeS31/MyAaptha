package com.myaaptha.platform.security;

import static org.junit.jupiter.api.Assertions.*;
import com.myaaptha.domain.relationship.RelationshipRepository;
import com.myaaptha.domain.relationship.model.RelationshipEntity;
import com.myaaptha.domain.finance.FinancialTransactionEntity;
import com.myaaptha.domain.finance.FinancialTransactionRepository;
import java.math.BigDecimal;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import jakarta.persistence.EntityManager;

@SpringBootTest(properties = {"security.fields.enabled=true", "security.fields.allow-legacy-reads=true",
    "security.fields.keys=primary=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE="})
@Transactional
class EncryptedStorageTest {
  @Autowired RelationshipRepository relationships;
  @Autowired FinancialTransactionRepository finances;
  @Autowired JdbcTemplate jdbc;
  @Autowired EntityManager entities;

  @Test void privateContactsAndAmountsAreEncryptedAtRestAndReadNormally() {
    Long user = jdbc.queryForObject("SELECT MIN(id) FROM users", Long.class);
    var relation = new RelationshipEntity(); relation.setType("Friend"); relation.setOwnerUserId(user);
    relation.setContactName("Private Name"); relation.setContactPhone("+19995550123"); relation.setContactEmail("private@test.invalid");
    relation = relationships.saveAndFlush(relation);
    String stored = jdbc.queryForObject("SELECT contact_phone FROM relationships WHERE id=?", String.class, relation.getId());
    assertTrue(stored.startsWith("enc:v1:primary:")); assertFalse(stored.contains("19995550123"));
    entities.clear();
    assertEquals("+19995550123", relationships.findById(relation.getId()).orElseThrow().getContactPhone());
    var transaction = new FinancialTransactionEntity(); transaction.setUserId(user); transaction.setAmount(new BigDecimal("125.50"));
    transaction.setDirection("EXPENSE"); transaction.setCategory("OTHER"); transaction.setSource("MANUAL"); transaction.setOccurredAt(Instant.now());
    transaction = finances.saveAndFlush(transaction);
    assertTrue(jdbc.queryForObject("SELECT amount FROM financial_transactions WHERE id=?", String.class, transaction.getId()).startsWith("enc:v1:primary:"));
    entities.clear();
    assertEquals(0, new BigDecimal("125.50").compareTo(finances.findById(transaction.getId()).orElseThrow().getAmount()));
  }
}

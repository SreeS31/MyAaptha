package com.myaaptha.domain.finance;
import java.time.Instant;import java.util.*;import org.springframework.data.jpa.repository.JpaRepository;
public interface FinancialTransactionRepository extends JpaRepository<FinancialTransactionEntity,Long>{
 @org.springframework.data.jpa.repository.Query("select t from FinancialTransactionEntity t where t.userId = :userId and t.occurredAt >= :from and t.occurredAt < :to order by t.occurredAt desc")
 List<FinancialTransactionEntity> findInMonth(@org.springframework.data.repository.query.Param("userId") Long userId,@org.springframework.data.repository.query.Param("from") Instant from,@org.springframework.data.repository.query.Param("to") Instant to);
 Optional<FinancialTransactionEntity> findByUserIdAndSourceFingerprint(Long userId,String fingerprint);
}


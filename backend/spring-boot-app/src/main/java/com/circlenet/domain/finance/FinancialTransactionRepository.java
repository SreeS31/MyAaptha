package com.circlenet.domain.finance;
import java.time.Instant;import java.util.*;import org.springframework.data.jpa.repository.JpaRepository;
public interface FinancialTransactionRepository extends JpaRepository<FinancialTransactionEntity,Long>{List<FinancialTransactionEntity> findByUserIdAndOccurredAtBetweenOrderByOccurredAtDesc(Long userId,Instant from,Instant to);Optional<FinancialTransactionEntity> findByUserIdAndSourceFingerprint(Long userId,String fingerprint);}


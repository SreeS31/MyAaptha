package com.myaaptha.domain.message;

import com.myaaptha.domain.message.model.DirectCallEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DirectCallRepository extends JpaRepository<DirectCallEntity,Long> {
  List<DirectCallEntity> findByRecipientUserIdAndStatusAndCreatedAtAfterOrderByCreatedAtDesc(Long recipientUserId,String status,java.time.Instant after);
}

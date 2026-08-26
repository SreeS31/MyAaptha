package com.myaaptha.domain.message;
import com.myaaptha.domain.message.model.DirectMessageReactionEntity;import java.util.*;import org.springframework.data.jpa.repository.JpaRepository;
public interface DirectMessageReactionRepository extends JpaRepository<DirectMessageReactionEntity,Long>{List<DirectMessageReactionEntity> findByMessageId(Long messageId);Optional<DirectMessageReactionEntity> findByMessageIdAndUserId(Long messageId,Long userId);}

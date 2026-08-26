package com.myaaptha.domain.message;

import com.myaaptha.domain.message.model.DirectMessageEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DirectMessageRepository extends JpaRepository<DirectMessageEntity,Long> {
  @Query("select message from DirectMessageEntity message where (message.senderUserId=:first and message.recipientUserId=:second) or (message.senderUserId=:second and message.recipientUserId=:first) order by message.createdAt asc, message.id asc")
  List<DirectMessageEntity> conversation(@Param("first") Long first,@Param("second") Long second);
  List<DirectMessageEntity> findBySenderUserIdOrRecipientUserIdOrderByCreatedAtDescIdDesc(Long senderUserId,Long recipientUserId);
}

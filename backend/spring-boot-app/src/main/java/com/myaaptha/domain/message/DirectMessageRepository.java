package com.myaaptha.domain.message;

import com.myaaptha.domain.message.model.DirectMessageEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DirectMessageRepository extends JpaRepository<DirectMessageEntity,Long> {
  @Query(value="SELECT m.* FROM direct_messages m JOIN direct_message_flags f ON f.message_id=m.id AND f.user_id=:owner WHERE ((m.sender_user_id=:owner AND m.recipient_user_id=:other) OR (m.sender_user_id=:other AND m.recipient_user_id=:owner)) AND ((m.sender_user_id=:owner AND m.sender_hidden=FALSE) OR (m.recipient_user_id=:owner AND m.recipient_hidden=FALSE)) AND m.deleted_at IS NULL AND m.id<:before AND ((:kind='starred' AND f.starred=TRUE) OR (:kind='pinned' AND f.pinned=TRUE)) ORDER BY m.id DESC",nativeQuery=true)
  List<DirectMessageEntity> saved(@Param("owner") Long owner,@Param("other") Long other,@Param("kind") String kind,@Param("before") Long before,org.springframework.data.domain.Pageable pageable);
  @Query("select message from DirectMessageEntity message where (message.senderUserId=:first and message.recipientUserId=:second) or (message.senderUserId=:second and message.recipientUserId=:first) order by message.createdAt asc, message.id asc")
  List<DirectMessageEntity> conversation(@Param("first") Long first,@Param("second") Long second);
  List<DirectMessageEntity> findBySenderUserIdOrRecipientUserIdOrderByCreatedAtDescIdDesc(Long senderUserId,Long recipientUserId);

  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select m from DirectMessageEntity m where ((m.senderUserId=:first and m.recipientUserId=:second) or (m.senderUserId=:second and m.recipientUserId=:first)) and m.id<:before order by m.id desc")
  List<DirectMessageEntity> page(@Param("first") Long first,@Param("second") Long second,@Param("before") Long before,org.springframework.data.domain.Pageable pageable);
  @Query("select m from DirectMessageEntity m where ((m.senderUserId=:first and m.recipientUserId=:second) or (m.senderUserId=:second and m.recipientUserId=:first)) and ((m.senderUserId=:first and m.senderHidden=false) or (m.recipientUserId=:first and m.recipientHidden=false)) and m.deletedAt is null and (locate(:q,lower(m.message))>0 or locate(:q,lower(m.attachmentName))>0) order by m.id desc")
  List<DirectMessageEntity> search(@Param("first") Long first,@Param("second") Long second,@Param("q") String q,org.springframework.data.domain.Pageable pageable);
  @Query(value="SELECT m.* FROM direct_messages m JOIN (SELECT MAX(d.id) AS latest_id FROM direct_messages d WHERE (d.sender_user_id=:userId AND d.sender_hidden=FALSE) OR (d.recipient_user_id=:userId AND d.recipient_hidden=FALSE) GROUP BY CASE WHEN d.sender_user_id=:userId THEN d.recipient_user_id ELSE d.sender_user_id END) inbox ON m.id=inbox.latest_id ORDER BY m.id DESC",nativeQuery=true)
  List<DirectMessageEntity> latestConversations(@Param("userId") Long userId);
  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select m from DirectMessageEntity m where m.id=:id")
  java.util.Optional<DirectMessageEntity> locked(@Param("id") Long id);
  interface UnreadCount { Long getSenderId(); Long getUnreadCount(); }
  @Query(value="SELECT sender_user_id AS senderId,COUNT(*) AS unreadCount FROM direct_messages WHERE recipient_user_id=:userId AND recipient_hidden=FALSE AND deleted_at IS NULL AND read_at IS NULL GROUP BY sender_user_id",nativeQuery=true)
  List<UnreadCount> unreadCounts(@Param("userId") Long userId);
}

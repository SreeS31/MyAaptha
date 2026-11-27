-- Pending private groupings accumulate across import batches; contacts are never invited here.
CREATE TABLE address_book_circle_candidates (
 owner_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 contact_id BIGINT NOT NULL REFERENCES address_book_contacts(id) ON DELETE CASCADE,
 normalized_name VARCHAR(100) NOT NULL,
 circle_name VARCHAR(100) NOT NULL,
 PRIMARY KEY(owner_user_id,contact_id,normalized_name)
);
ALTER TABLE circles ADD COLUMN auto_organized BOOLEAN NOT NULL DEFAULT FALSE;
-- The previous organizer used this exact system description. Preserve the source labels before cleanup.
INSERT INTO address_book_circle_candidates(owner_user_id,contact_id,normalized_name,circle_name)
 SELECT DISTINCT c.owner_user_id,a.id,LOWER(TRIM(c.name)),c.name
 FROM circles c JOIN address_book_circle_contacts cc ON cc.circle_id=c.id
 JOIN address_book_contacts a ON a.id=cc.contact_id AND a.user_id=c.owner_user_id
 WHERE CHAR_LENGTH(c.name)<=100 AND c.description='Automatically organized private contacts. Only explicitly invited members can join conversations.';
UPDATE circles SET auto_organized=TRUE
 WHERE CHAR_LENGTH(name)<=100 AND description='Automatically organized private contacts. Only explicitly invited members can join conversations.'
 AND EXISTS(SELECT 1 FROM address_book_circle_contacts cc WHERE cc.circle_id=circles.id);
-- Remove only unused generated scaffolds, never a manual circle or a circle with activity/settings.
DELETE FROM circles WHERE auto_organized=TRUE AND posting_permission='ALL_MEMBERS'
 AND (SELECT COUNT(*) FROM address_book_circle_contacts cc WHERE cc.circle_id=circles.id)<3
 AND NOT EXISTS(SELECT 1 FROM circle_members m WHERE m.circle_id=circles.id AND m.user_id<>circles.owner_user_id)
 AND NOT EXISTS(SELECT 1 FROM circle_admins a WHERE a.circle_id=circles.id AND a.user_id<>circles.owner_user_id)
 AND NOT EXISTS(SELECT 1 FROM address_book_circle_contacts cc JOIN address_book_contacts a ON a.id=cc.contact_id WHERE cc.circle_id=circles.id AND a.user_id<>circles.owner_user_id)
 AND NOT EXISTS(SELECT 1 FROM circle_posts p WHERE p.circle_id=circles.id)
 AND NOT EXISTS(SELECT 1 FROM social_posts p WHERE p.circle_id=circles.id)
 AND NOT EXISTS(SELECT 1 FROM community_activities a WHERE a.circle_id=circles.id)
 AND NOT EXISTS(SELECT 1 FROM communication_calls c WHERE c.scope='CIRCLE' AND c.target_id=circles.id)
 AND NOT EXISTS(SELECT 1 FROM chat_workspace_options o WHERE o.kind='CIRCLE' AND o.target_id=circles.id)
 AND NOT EXISTS(SELECT 1 FROM chat_message_retention r WHERE r.kind='CIRCLE' AND r.first_id=circles.id);

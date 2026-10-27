ALTER TABLE social_post_likes ADD COLUMN reaction VARCHAR(32) NOT NULL DEFAULT '👍';
CREATE TABLE social_post_flags (
  post_id BIGINT NOT NULL REFERENCES social_posts(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pinned BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (post_id,user_id)
);
CREATE INDEX idx_social_post_flags_user ON social_post_flags(user_id,pinned);

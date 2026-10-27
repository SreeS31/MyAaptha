CREATE TABLE direct_chat_settings (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  other_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  muted BOOLEAN NOT NULL DEFAULT FALSE,
  marked_unread BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, other_user_id),
  CHECK (user_id <> other_user_id)
);

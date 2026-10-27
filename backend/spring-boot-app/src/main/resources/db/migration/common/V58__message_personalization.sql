CREATE TABLE direct_message_flags (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_id BIGINT NOT NULL REFERENCES direct_messages(id) ON DELETE CASCADE,
  starred BOOLEAN NOT NULL DEFAULT FALSE,
  pinned BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, message_id)
);
CREATE INDEX idx_message_flags_saved ON direct_message_flags(user_id, starred, pinned, message_id);
CREATE TABLE direct_chat_pins (
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  other_user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY(user_id, other_user_id)
);
CREATE TABLE message_preferences (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  read_receipts BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE direct_messages ADD COLUMN sender_hidden BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE direct_messages ADD COLUMN recipient_hidden BOOLEAN NOT NULL DEFAULT FALSE;
CREATE TABLE circle_post_hidden (
 post_id BIGINT NOT NULL REFERENCES circle_posts(id) ON DELETE CASCADE,
 user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 PRIMARY KEY(post_id,user_id)
);
CREATE INDEX idx_circle_post_hidden_user ON circle_post_hidden(user_id,post_id);

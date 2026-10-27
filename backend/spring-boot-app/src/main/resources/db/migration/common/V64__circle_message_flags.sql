ALTER TABLE circle_posts ADD COLUMN forwarded BOOLEAN NOT NULL DEFAULT FALSE;
CREATE TABLE circle_post_stars (post_id BIGINT NOT NULL REFERENCES circle_posts(id) ON DELETE CASCADE, user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY(post_id,user_id));
CREATE INDEX idx_circle_stars_user ON circle_post_stars(user_id,post_id);
CREATE TABLE circle_post_pins (post_id BIGINT NOT NULL REFERENCES circle_posts(id) ON DELETE CASCADE, user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY(post_id,user_id));
CREATE INDEX idx_circle_pins_user ON circle_post_pins(user_id,post_id);

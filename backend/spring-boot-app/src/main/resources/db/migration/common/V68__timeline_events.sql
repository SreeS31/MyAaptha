CREATE TABLE timeline_events (
 user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 event_key VARCHAR(100) NOT NULL,
 event_date VARCHAR(10) NOT NULL,
 kind VARCHAR(30) NOT NULL,
 title VARCHAR(200) NOT NULL,
 detail VARCHAR(2000) NOT NULL,
 PRIMARY KEY (user_id, event_key)
);

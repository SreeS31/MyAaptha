CREATE TABLE chat_workspace_options (
 user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 kind VARCHAR(6) NOT NULL CHECK (kind IN ('DIRECT','CIRCLE')),
 target_id BIGINT NOT NULL,
 favourite BOOLEAN NOT NULL DEFAULT FALSE,
 archived BOOLEAN NOT NULL DEFAULT FALSE,
 muted_until TIMESTAMP WITH TIME ZONE,
 theme VARCHAR(12) NOT NULL DEFAULT 'DEFAULT',
 list_name VARCHAR(60) NOT NULL DEFAULT '',
 PRIMARY KEY(user_id,kind,target_id)
);
CREATE TABLE chat_message_retention (
 kind VARCHAR(6) NOT NULL CHECK (kind IN ('DIRECT','CIRCLE')),
 first_id BIGINT NOT NULL,
 second_id BIGINT NOT NULL,
 seconds INTEGER NOT NULL CHECK(seconds IN (0,86400,604800,7776000)),
 PRIMARY KEY(kind,first_id,second_id)
);
CREATE TABLE chat_message_expiry (
 kind VARCHAR(6) NOT NULL CHECK (kind IN ('DIRECT','CIRCLE')),
 message_id BIGINT NOT NULL,
 expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
 PRIMARY KEY(kind,message_id)
);
CREATE INDEX idx_chat_message_expiry_due ON chat_message_expiry(expires_at);

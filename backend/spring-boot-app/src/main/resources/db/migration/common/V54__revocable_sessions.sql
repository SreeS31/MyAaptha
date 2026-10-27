ALTER TABLE auth_tokens ADD COLUMN session_id VARCHAR(36);
CREATE UNIQUE INDEX idx_auth_session ON auth_tokens(session_id);

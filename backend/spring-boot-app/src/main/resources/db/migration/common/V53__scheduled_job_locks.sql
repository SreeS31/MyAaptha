CREATE TABLE scheduled_job_locks (name VARCHAR(80) PRIMARY KEY);
INSERT INTO scheduled_job_locks(name) VALUES ('media-retention'), ('story-retention');
CREATE INDEX idx_auth_tokens_user_type ON auth_tokens(user_id,token_type);

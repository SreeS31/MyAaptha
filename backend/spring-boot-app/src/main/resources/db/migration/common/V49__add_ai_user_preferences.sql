CREATE TABLE ai_user_preferences (
    user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    ai_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    allow_sensitive_data BOOLEAN NOT NULL DEFAULT FALSE,
    allow_personalization BOOLEAN NOT NULL DEFAULT FALSE,
    activity_retention_days INTEGER NOT NULL DEFAULT 90,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_ai_activity_retention CHECK (activity_retention_days BETWEEN 0 AND 365)
);

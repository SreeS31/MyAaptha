CREATE TABLE help_ai_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    enhanced_enabled BOOLEAN NOT NULL DEFAULT FALSE
);
INSERT INTO help_ai_settings(id, enhanced_enabled) VALUES (1, FALSE);

CREATE TABLE help_exchanges (
    id VARCHAR(36) PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cache_key VARCHAR(64) NOT NULL,
    tier VARCHAR(16) NOT NULL,
    mode VARCHAR(16) NOT NULL,
    model VARCHAR(80) NOT NULL,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    payload TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_help_exchange_owner_cache ON help_exchanges(user_id, cache_key, created_at DESC);
CREATE INDEX idx_help_exchange_expiry ON help_exchanges(expires_at);

-- Only explicitly reviewed, public application help belongs here.
CREATE TABLE help_shared_answers (
    question_key VARCHAR(64) PRIMARY KEY,
    knowledge_version VARCHAR(64) NOT NULL,
    payload TEXT NOT NULL,
    approved_by BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

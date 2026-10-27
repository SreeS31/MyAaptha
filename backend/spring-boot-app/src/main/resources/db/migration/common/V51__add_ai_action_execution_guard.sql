ALTER TABLE ai_action_approvals
    ADD COLUMN authorization_expires_at TIMESTAMP WITH TIME ZONE;

CREATE TABLE ai_action_executions (
    id UUID PRIMARY KEY,
    approval_id UUID NOT NULL UNIQUE REFERENCES ai_action_approvals(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key_hash VARCHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL,
    failure_code VARCHAR(80),
    result_reference VARCHAR(240),
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_ai_action_execution_status CHECK (
        status IN ('RUNNING', 'SUCCEEDED', 'FAILED'))
);

CREATE INDEX idx_ai_action_executions_user_started
    ON ai_action_executions(user_id, started_at DESC);

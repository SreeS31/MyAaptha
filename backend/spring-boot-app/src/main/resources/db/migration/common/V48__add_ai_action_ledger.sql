CREATE TABLE ai_action_events (
    id BIGSERIAL PRIMARY KEY,
    request_id UUID NOT NULL UNIQUE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    capability VARCHAR(80) NOT NULL,
    action_level VARCHAR(2) NOT NULL,
    purpose VARCHAR(240) NOT NULL,
    consent_granted BOOLEAN NOT NULL DEFAULT FALSE,
    approval_state VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    failure_code VARCHAR(80),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_ai_action_level CHECK (action_level IN ('L0', 'L1', 'L2', 'L3', 'L4')),
    CONSTRAINT chk_ai_approval_state CHECK (approval_state IN ('NOT_REQUIRED', 'REQUIRED', 'APPROVED', 'REJECTED')),
    CONSTRAINT chk_ai_action_status CHECK (status IN ('STARTED', 'SUCCEEDED', 'FAILED', 'REJECTED'))
);

CREATE INDEX idx_ai_action_events_user_created ON ai_action_events(user_id, created_at DESC);
CREATE INDEX idx_ai_action_events_status_created ON ai_action_events(status, created_at DESC);

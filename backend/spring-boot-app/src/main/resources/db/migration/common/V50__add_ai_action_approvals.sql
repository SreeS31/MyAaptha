CREATE TABLE ai_action_approvals (
    id UUID PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    capability VARCHAR(80) NOT NULL,
    action_level VARCHAR(2) NOT NULL,
    title VARCHAR(120) NOT NULL,
    summary VARCHAR(500) NOT NULL,
    resource_type VARCHAR(80),
    resource_id VARCHAR(120),
    action_fingerprint VARCHAR(64) NOT NULL,
    pending_fingerprint VARCHAR(64),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    decision_reason VARCHAR(240),
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    decided_at TIMESTAMP WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_ai_approval_level CHECK (action_level IN ('L2', 'L3')),
    CONSTRAINT chk_ai_action_approval_status CHECK (
        status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT chk_ai_action_approval_expiry CHECK (expires_at > requested_at)
);

CREATE INDEX idx_ai_action_approvals_user_status_requested
    ON ai_action_approvals(user_id, status, requested_at DESC);

CREATE UNIQUE INDEX uq_ai_action_approval_pending_fingerprint
    ON ai_action_approvals(user_id, pending_fingerprint);

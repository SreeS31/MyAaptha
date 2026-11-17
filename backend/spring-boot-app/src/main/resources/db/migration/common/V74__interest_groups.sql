CREATE TABLE interest_groups (
 id VARCHAR(36) PRIMARY KEY,
 owner_user_id BIGINT NOT NULL REFERENCES users(id),
 name VARCHAR(160) NOT NULL,
 topic VARCHAR(120) NOT NULL,
 area VARCHAR(200) NOT NULL,
 description TEXT NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_interest_groups_created ON interest_groups(created_at, id);
CREATE INDEX idx_interest_groups_owner ON interest_groups(owner_user_id);
CREATE TABLE interest_group_members (
 group_id VARCHAR(36) NOT NULL REFERENCES interest_groups(id) ON DELETE CASCADE,
 user_id BIGINT NOT NULL REFERENCES users(id),
 status VARCHAR(16) NOT NULL CHECK (status IN ('ACTIVE','REQUESTED','REJECTED','LEFT')),
 requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(group_id,user_id)
);
CREATE INDEX idx_interest_group_user ON interest_group_members(user_id,status);
CREATE INDEX idx_interest_group_requests ON interest_group_members(group_id,status,requested_at);
CREATE TABLE interest_group_messages (
 id VARCHAR(36) PRIMARY KEY,
 group_id VARCHAR(36) NOT NULL REFERENCES interest_groups(id) ON DELETE CASCADE,
 author_user_id BIGINT NOT NULL REFERENCES users(id),
 body TEXT NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_interest_group_messages ON interest_group_messages(group_id,created_at,id);

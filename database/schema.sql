-- MyAaptha MySQL 8 Schema
-- Run: mysql -u root -p < database/schema.sql

CREATE DATABASE IF NOT EXISTS myaaptha
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE myaaptha;

-- ============================================================
-- USERS & AUTHENTICATION
-- ============================================================

CREATE TABLE users (
    id              CHAR(36) PRIMARY KEY,
    email           VARCHAR(255) UNIQUE,
    mobile          VARCHAR(20) UNIQUE,
    password_hash   VARCHAR(255),
    full_name       VARCHAR(255) NOT NULL,
    avatar_url      VARCHAR(512),
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    email_verified  BOOLEAN DEFAULT FALSE,
    mobile_verified BOOLEAN DEFAULT FALSE,
    status          ENUM('ACTIVE','INACTIVE','SUSPENDED','DELETED') DEFAULT 'ACTIVE',
    preferred_language VARCHAR(10) DEFAULT 'en',
    timezone        VARCHAR(64) DEFAULT 'UTC',
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_login_at   TIMESTAMP NULL,
    INDEX idx_users_status (status)
) ENGINE=InnoDB;

CREATE TABLE user_roles (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    role        ENUM('SUPER_ADMIN','ADMIN','OWNER','EDITOR','VIEWER','GUEST') NOT NULL,
    scope_type  ENUM('GLOBAL','CIRCLE') DEFAULT 'GLOBAL',
    scope_id    CHAR(36) NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uk_user_role_scope (user_id, role, scope_type, scope_id)
) ENGINE=InnoDB;

CREATE TABLE oauth_accounts (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id         CHAR(36) NOT NULL,
    provider        ENUM('GOOGLE','FACEBOOK','APPLE') NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    access_token    TEXT,
    refresh_token   TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uk_oauth_provider (provider, provider_user_id)
) ENGINE=InnoDB;

CREATE TABLE otp_tokens (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    identifier  VARCHAR(255) NOT NULL,
    channel     ENUM('EMAIL','MOBILE') NOT NULL,
    otp_hash    VARCHAR(255) NOT NULL,
    purpose     ENUM('LOGIN','REGISTER','RESET_PASSWORD','VERIFY') NOT NULL,
    expires_at  TIMESTAMP NOT NULL,
    used        BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_otp_identifier (identifier, purpose, used)
) ENGINE=InnoDB;

CREATE TABLE refresh_tokens (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    token_hash  VARCHAR(255) NOT NULL UNIQUE,
    device_id   CHAR(36),
    expires_at  TIMESTAMP NOT NULL,
    revoked     BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE devices (
    id              CHAR(36) PRIMARY KEY,
    user_id         CHAR(36) NOT NULL,
    device_name     VARCHAR(255),
    device_type     ENUM('WEB','ANDROID','IOS','DESKTOP') NOT NULL,
    fingerprint     VARCHAR(255),
    trusted         BOOLEAN DEFAULT FALSE,
    last_ip         VARCHAR(45),
    last_active_at  TIMESTAMP,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE login_history (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    success     BOOLEAN NOT NULL,
    method      ENUM('EMAIL','MOBILE_OTP','GOOGLE','FACEBOOK','APPLE','PASSWORD') NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_login_user_date (user_id, created_at)
) ENGINE=InnoDB;

-- ============================================================
-- CIRCLES & TREES
-- ============================================================

CREATE TABLE circles (
    id              CHAR(36) PRIMARY KEY,
    owner_id        CHAR(36) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    category        ENUM('FAMILY','FRIENDS','RELATIVES','OFFICE','COMPANY','COLLEGE','SCHOOL',
                         'BUSINESS','VILLAGE','APARTMENT','COMMUNITY','SOCIETY','TEMPLE','SPORTS',
                         'POLITICS','HOBBY','PHOTOGRAPHY','MUSIC','TRAVEL','CUSTOMERS','EMPLOYEES',
                         'VOLUNTEERS','CUSTOM') DEFAULT 'CUSTOM',
    tree_type       ENUM('PRIVATE','PUBLIC','FRIENDS','FAMILY','RELATIVES','COMMUNITY',
                         'ORGANIZATION','INVITATION_ONLY','HIDDEN','PASSWORD_PROTECTED') DEFAULT 'PRIVATE',
    visibility      ENUM('PRIVATE','FRIENDS','RELATIVES','COMMUNITY','PUBLIC','HIDDEN') DEFAULT 'PRIVATE',
    password_hash   VARCHAR(255),
    archived        BOOLEAN DEFAULT FALSE,
    health_score    INT DEFAULT 100,
    member_count    INT DEFAULT 0,
    node_count      INT DEFAULT 0,
    template_id     CHAR(36),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES users(id),
    INDEX idx_circles_owner (owner_id),
    INDEX idx_circles_category (category)
) ENGINE=InnoDB;

CREATE TABLE circle_members (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    circle_id   CHAR(36) NOT NULL,
    user_id     CHAR(36) NOT NULL,
    role        ENUM('OWNER','EDITOR','VIEWER','GUEST') NOT NULL DEFAULT 'VIEWER',
    invited_by  CHAR(36),
    joined_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uk_circle_member (circle_id, user_id)
) ENGINE=InnoDB;

CREATE TABLE tree_templates (
    id          CHAR(36) PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    category    VARCHAR(64),
    structure_json JSON NOT NULL,
    is_public   BOOLEAN DEFAULT TRUE,
    created_by  CHAR(36),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE tree_versions (
    id          CHAR(36) PRIMARY KEY,
    circle_id   CHAR(36) NOT NULL,
    version_number INT NOT NULL,
    snapshot_json LONGTEXT NOT NULL,
    created_by  CHAR(36) NOT NULL,
    comment     VARCHAR(512),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
    UNIQUE KEY uk_circle_version (circle_id, version_number)
) ENGINE=InnoDB;

CREATE TABLE tree_links (
    id                  CHAR(36) PRIMARY KEY,
    source_circle_id    CHAR(36) NOT NULL,
    target_circle_id    CHAR(36) NOT NULL,
    source_node_id      CHAR(36) NOT NULL,
    target_node_id      CHAR(36) NOT NULL,
    link_type           ENUM('SPOUSE','SHARED_CHILDREN') DEFAULT 'SPOUSE',
    editable_in_target  BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (source_circle_id) REFERENCES circles(id) ON DELETE CASCADE,
    FOREIGN KEY (target_circle_id) REFERENCES circles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- PERSON NODES
-- ============================================================

CREATE TABLE person_nodes (
    id              CHAR(36) PRIMARY KEY,
    circle_id       CHAR(36) NOT NULL,
    parent_id       CHAR(36),
    linked_user_id  CHAR(36),
    full_name       VARCHAR(255) NOT NULL,
    nick_name       VARCHAR(128),
    gender          ENUM('MALE','FEMALE','UNKNOWN') DEFAULT 'UNKNOWN',
    date_of_birth   DATE,
    blood_group     VARCHAR(8),
    marital_status  ENUM('SINGLE','MARRIED','DIVORCED','WIDOWED','OTHER'),
    occupation      VARCHAR(255),
    company         VARCHAR(255),
    designation     VARCHAR(255),
    education       TEXT,
    nationality     VARCHAR(64),
    religion        VARCHAR(64),
    biography       TEXT,
    notes           TEXT,
    profile_json    JSON,
    profile_picture_url VARCHAR(512),
    latitude        DECIMAL(10,8),
    longitude       DECIMAL(11,8),
    country         VARCHAR(64),
    state           VARCHAR(64),
    city            VARCHAR(64),
    district        VARCHAR(64),
    village         VARCHAR(128),
    address         TEXT,
    is_deceased     BOOLEAN DEFAULT FALSE,
    deceased_date   DATE,
    version         INT DEFAULT 0,
    created_by      CHAR(36),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES person_nodes(id) ON DELETE SET NULL,
    FOREIGN KEY (linked_user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_nodes_circle (circle_id),
    INDEX idx_nodes_parent (circle_id, parent_id),
    FULLTEXT INDEX ft_nodes_name (full_name, nick_name, company, city)
) ENGINE=InnoDB;

CREATE TABLE node_contacts (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    node_id     CHAR(36) NOT NULL,
    contact_type ENUM('EMAIL','MOBILE','WHATSAPP','TELEGRAM','SIGNAL','FACEBOOK',
                      'INSTAGRAM','LINKEDIN','TWITTER','YOUTUBE','WEBSITE') NOT NULL,
    value       VARCHAR(512) NOT NULL,
    is_primary  BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (node_id) REFERENCES person_nodes(id) ON DELETE CASCADE,
    INDEX idx_contacts_value (contact_type, value(100))
) ENGINE=InnoDB;

CREATE TABLE node_media (
    id          CHAR(36) PRIMARY KEY,
    node_id     CHAR(36) NOT NULL,
    media_type  ENUM('PHOTO','VIDEO','VOICE') NOT NULL,
    storage_key VARCHAR(512) NOT NULL,
    url         VARCHAR(512),
    caption     VARCHAR(512),
    sort_order  INT DEFAULT 0,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES person_nodes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE node_documents (
    id          CHAR(36) PRIMARY KEY,
    node_id     CHAR(36) NOT NULL,
    doc_type    ENUM('ID_PROOF','CERTIFICATE','OTHER') DEFAULT 'OTHER',
    title       VARCHAR(255),
    storage_key VARCHAR(512) NOT NULL,
    mime_type   VARCHAR(128),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES person_nodes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE node_tags (
    node_id     CHAR(36) NOT NULL,
    tag         VARCHAR(64) NOT NULL,
    PRIMARY KEY (node_id, tag),
    FOREIGN KEY (node_id) REFERENCES person_nodes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE node_custom_fields (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    node_id     CHAR(36) NOT NULL,
    field_key   VARCHAR(128) NOT NULL,
    field_value TEXT,
    FOREIGN KEY (node_id) REFERENCES person_nodes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE emergency_contacts (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    node_id     CHAR(36) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    relationship VARCHAR(128),
    phone       VARCHAR(32),
    email       VARCHAR(255),
    priority    INT DEFAULT 1,
    FOREIGN KEY (node_id) REFERENCES person_nodes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Closure table for efficient hierarchy queries
CREATE TABLE node_closure (
    ancestor_id     CHAR(36) NOT NULL,
    descendant_id   CHAR(36) NOT NULL,
    depth           INT NOT NULL,
    circle_id       CHAR(36) NOT NULL,
    PRIMARY KEY (ancestor_id, descendant_id),
    INDEX idx_closure_descendant (descendant_id, depth),
    INDEX idx_closure_circle (circle_id, ancestor_id)
) ENGINE=InnoDB;

-- ============================================================
-- RELATIONSHIPS
-- ============================================================

CREATE TABLE relationship_types (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(64) NOT NULL UNIQUE,
    label       VARCHAR(128) NOT NULL,
    category    ENUM('FAMILY','SOCIAL','PROFESSIONAL','CUSTOM') DEFAULT 'FAMILY',
    bidirectional_default BOOLEAN DEFAULT FALSE,
    is_system   BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE relationships (
    id              CHAR(36) PRIMARY KEY,
    circle_id       CHAR(36) NOT NULL,
    source_node_id  CHAR(36) NOT NULL,
    target_node_id  CHAR(36) NOT NULL,
    relationship_type VARCHAR(64) NOT NULL,
    bidirectional   BOOLEAN DEFAULT FALSE,
    label_override  VARCHAR(128),
    metadata_json   JSON,
    created_by      CHAR(36),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
    FOREIGN KEY (source_node_id) REFERENCES person_nodes(id) ON DELETE CASCADE,
    FOREIGN KEY (target_node_id) REFERENCES person_nodes(id) ON DELETE CASCADE,
    INDEX idx_rel_source (source_node_id, relationship_type),
    INDEX idx_rel_target (target_node_id, relationship_type),
    UNIQUE KEY uk_relationship (circle_id, source_node_id, target_node_id, relationship_type)
) ENGINE=InnoDB;

-- ============================================================
-- PERMISSIONS (ACL)
-- ============================================================

CREATE TABLE acl_entries (
    id              CHAR(36) PRIMARY KEY,
    circle_id       CHAR(36) NOT NULL,
    user_id         CHAR(36) NOT NULL,
    node_id         CHAR(36),
    scope_type      ENUM('TREE','BRANCH','NODE','DEPTH','LEVEL','SIBLINGS','PARENTS','CHILDREN') DEFAULT 'TREE',
    depth_limit     INT,
    level_limit     INT,
    permissions     SET('VIEW','EDIT','DELETE','MOVE','CREATE_CHILD','CREATE_PARENT',
                        'INVITE','EXPORT','PRINT','SHARE','TRANSFER_OWNERSHIP') NOT NULL,
    granted_by      CHAR(36),
    expires_at      TIMESTAMP NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_acl_user_circle (user_id, circle_id)
) ENGINE=InnoDB;

-- ============================================================
-- COMMUNICATION & EVENTS
-- ============================================================

CREATE TABLE messages (
    id          CHAR(36) PRIMARY KEY,
    circle_id   CHAR(36),
    sender_id   CHAR(36) NOT NULL,
    channel     ENUM('SMS','WHATSAPP','TELEGRAM','SIGNAL','EMAIL','PUSH','IN_APP') NOT NULL,
    subject     VARCHAR(512),
    body        TEXT NOT NULL,
    filter_json JSON,
    sent_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE calendar_events (
    id          CHAR(36) PRIMARY KEY,
    circle_id   CHAR(36),
    node_id     CHAR(36),
    title       VARCHAR(255) NOT NULL,
    event_type  ENUM('BIRTHDAY','ANNIVERSARY','MEETING','FESTIVAL','CUSTOM') NOT NULL,
    event_date  DATE NOT NULL,
    recurrence  VARCHAR(64),
    created_by  CHAR(36),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (circle_id) REFERENCES circles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE reminders (
    id          CHAR(36) PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    node_id     CHAR(36),
    reminder_type ENUM('BIRTHDAY','ANNIVERSARY','INACTIVE_CONTACT','MISSING_DATA','CUSTOM') NOT NULL,
    remind_at   TIMESTAMP NOT NULL,
    sent        BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE notifications (
    id          CHAR(36) PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    title       VARCHAR(255) NOT NULL,
    body        TEXT,
    type        VARCHAR(64),
    read_flag   BOOLEAN DEFAULT FALSE,
    payload_json JSON,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_notif_user (user_id, read_flag, created_at)
) ENGINE=InnoDB;

-- ============================================================
-- AUDIT
-- ============================================================

-- ============================================================
-- HEALTH REPORTS & LAB RESULT HISTORY
-- ============================================================

CREATE TABLE health_reports (
    id          CHAR(36) PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    report_date DATE NOT NULL,
    file_name   VARCHAR(255) NOT NULL,
    mime_type   VARCHAR(100) NOT NULL,
    lab_name    VARCHAR(255),
    summary     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_health_report_user_date (user_id, report_date)
) ENGINE=InnoDB;

CREATE TABLE lab_results (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    report_id       CHAR(36) NOT NULL,
    panel_name      VARCHAR(255),
    test_name       VARCHAR(255) NOT NULL,
    normalized_name VARCHAR(255) NOT NULL,
    value           DOUBLE NOT NULL,
    unit            VARCHAR(40),
    reference_low   DOUBLE,
    reference_high  DOUBLE,
    status          VARCHAR(20) NOT NULL,
    suggestion      TEXT,
    FOREIGN KEY (report_id) REFERENCES health_reports(id) ON DELETE CASCADE,
    INDEX idx_lab_result_name (normalized_name),
    INDEX idx_lab_result_report (report_id)
) ENGINE=InnoDB;

CREATE TABLE audit_logs (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id         CHAR(36),
    circle_id       CHAR(36),
    entity_type     VARCHAR(64) NOT NULL,
    entity_id       CHAR(36) NOT NULL,
    action          ENUM('CREATE','UPDATE','DELETE','MERGE','SPLIT','CLONE','ROLLBACK') NOT NULL,
    previous_value  JSON,
    new_value       JSON,
    ip_address      VARCHAR(45),
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_entity (entity_type, entity_id, created_at),
    INDEX idx_audit_circle (circle_id, created_at)
) ENGINE=InnoDB;

-- ============================================================
-- SEED: System relationship types
-- ============================================================

INSERT INTO relationship_types (code, label, category, bidirectional_default) VALUES
('FATHER', 'Father', 'FAMILY', FALSE),
('MOTHER', 'Mother', 'FAMILY', FALSE),
('SON', 'Son', 'FAMILY', FALSE),
('DAUGHTER', 'Daughter', 'FAMILY', FALSE),
('BROTHER', 'Brother', 'FAMILY', TRUE),
('SISTER', 'Sister', 'FAMILY', TRUE),
('GRAND_FATHER', 'Grand Father', 'FAMILY', FALSE),
('GRAND_MOTHER', 'Grand Mother', 'FAMILY', FALSE),
('GRAND_SON', 'Grand Son', 'FAMILY', FALSE),
('GRAND_DAUGHTER', 'Grand Daughter', 'FAMILY', FALSE),
('UNCLE', 'Uncle', 'FAMILY', FALSE),
('AUNT', 'Aunt', 'FAMILY', FALSE),
('NEPHEW', 'Nephew', 'FAMILY', FALSE),
('NIECE', 'Niece', 'FAMILY', FALSE),
('COUSIN', 'Cousin', 'FAMILY', TRUE),
('SPOUSE', 'Spouse', 'FAMILY', TRUE),
('PARTNER', 'Partner', 'FAMILY', TRUE),
('FRIEND', 'Friend', 'SOCIAL', TRUE),
('BEST_FRIEND', 'Best Friend', 'SOCIAL', TRUE),
('CLASSMATE', 'Classmate', 'SOCIAL', TRUE),
('COLLEAGUE', 'Colleague', 'PROFESSIONAL', TRUE),
('MANAGER', 'Manager', 'PROFESSIONAL', FALSE),
('EMPLOYEE', 'Employee', 'PROFESSIONAL', FALSE),
('MENTOR', 'Mentor', 'PROFESSIONAL', FALSE),
('TEACHER', 'Teacher', 'PROFESSIONAL', FALSE),
('STUDENT', 'Student', 'PROFESSIONAL', FALSE),
('BUSINESS_PARTNER', 'Business Partner', 'PROFESSIONAL', TRUE),
('CUSTOMER', 'Customer', 'PROFESSIONAL', FALSE),
('VENDOR', 'Vendor', 'PROFESSIONAL', FALSE),
('DOCTOR', 'Doctor', 'PROFESSIONAL', FALSE),
('LAWYER', 'Lawyer', 'PROFESSIONAL', FALSE),
('NEIGHBOUR', 'Neighbour', 'SOCIAL', TRUE),
('COMMUNITY_MEMBER', 'Community Member', 'SOCIAL', TRUE);

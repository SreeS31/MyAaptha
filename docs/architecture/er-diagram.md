# MyAaptha — Entity Relationship Diagram

## Conceptual ER (Mermaid)

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : has
    USERS ||--o{ DEVICES : owns
    USERS ||--o{ LOGIN_HISTORY : generates
    USERS ||--o{ CIRCLES : owns
    USERS ||--o{ CIRCLE_MEMBERS : participates

    CIRCLES ||--o{ PERSON_NODES : contains
    CIRCLES ||--o{ TREE_VERSIONS : versions
    CIRCLES ||--o{ ACL_ENTRIES : governs
    CIRCLES ||--o{ TREE_LINKS : links

    PERSON_NODES ||--o{ PERSON_NODES : parent_of
    PERSON_NODES ||--o{ RELATIONSHIPS : source
    PERSON_NODES ||--o{ RELATIONSHIPS : target
    PERSON_NODES ||--o{ NODE_MEDIA : has
    PERSON_NODES ||--o{ NODE_DOCUMENTS : has
    PERSON_NODES ||--o{ NODE_CUSTOM_FIELDS : has
    PERSON_NODES ||--o{ NODE_TAGS : tagged
    PERSON_NODES ||--o{ NODE_CLOSURE : ancestor
    PERSON_NODES ||--o{ NODE_CLOSURE : descendant

    RELATIONSHIP_TYPES ||--o{ RELATIONSHIPS : types
    USERS ||--o{ AUDIT_LOGS : performs
    CIRCLES ||--o{ CALENDAR_EVENTS : schedules
    PERSON_NODES ||--o{ REMINDERS : triggers
    USERS ||--o{ NOTIFICATIONS : receives
    CIRCLES ||--o{ MESSAGES : sends

    USERS {
        uuid id PK
        varchar email UK
        varchar mobile UK
        varchar password_hash
        boolean two_factor_enabled
        enum status
        timestamp created_at
    }

    CIRCLES {
        uuid id PK
        uuid owner_id FK
        varchar name
        enum circle_category
        enum tree_type
        enum visibility
        boolean archived
        int health_score
        timestamp created_at
    }

    PERSON_NODES {
        uuid id PK
        uuid circle_id FK
        uuid parent_id FK
        varchar full_name
        enum gender
        date date_of_birth
        json profile_json
        int version
    }

    RELATIONSHIPS {
        uuid id PK
        uuid circle_id FK
        uuid source_node_id FK
        uuid target_node_id FK
        enum relationship_type
        boolean bidirectional
    }

    ACL_ENTRIES {
        uuid id PK
        uuid circle_id FK
        uuid user_id FK
        uuid node_id FK
        enum scope_type
        int depth_limit
        set permissions
    }

    AUDIT_LOGS {
        bigint id PK
        uuid user_id FK
        varchar entity_type
        uuid entity_id
        varchar action
        json previous_value
        json new_value
        timestamp created_at
    }
```

## Relationship Cardinality Notes

- **Users ↔ Circles:** Many-to-many via `circle_members` with role per membership.
- **Person nodes:** Self-referential `parent_id` plus explicit `relationships` for non-parent edges (spouse, friend, colleague).
- **Node closure:** Materialized transitive closure for O(1) ancestor queries at scale.
- **Tree links:** Many-to-many between circles when spouses belong to different trees.

## Index Strategy

| Table | Index | Purpose |
|-------|-------|---------|
| person_nodes | (circle_id, parent_id) | Child enumeration |
| person_nodes | FULLTEXT(full_name) | Name search |
| node_closure | (ancestor_id, depth) | Subtree queries |
| relationships | (source_node_id, type) | Kinship traversal |
| acl_entries | (user_id, circle_id) | Permission lookup |
| audit_logs | (entity_type, entity_id, created_at) | History timeline |

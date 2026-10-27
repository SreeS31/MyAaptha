# MyAaptha 2036 Architecture

## Product Mission

MyAaptha is a private life coordination platform: relationships, circles, communication, memories, documents, health, wealth, goals, and carefully governed AI assistance in one consistent web and mobile workspace. The platform optimizes for user agency and long-term trust, not engagement at any cost.

## Non-Negotiable Principles

1. Server authorization and validation are authoritative.
2. Private data is never used for model training without separate, explicit opt-in.
3. AI proposes before it acts. Consequential actions require human approval.
4. Every AI action has a purpose, input scope, permission, explanation, audit record, and rollback strategy.
5. Web and mobile share domain language, information architecture, API contracts, and design tokens.
6. Data is durable, exportable, recoverable, region-aware, and deletable according to policy.
7. Scale through stateless services, queues, caches, partitioning, and observability, not premature microservice fragmentation.

## Scale Envelope

- 10 million registered users; 1 million daily active users.
- Hundreds of relationship nodes per user and dozens of circles.
- Billions of messages and document metadata rows over platform lifetime.
- Large media objects stored outside PostgreSQL in encrypted object storage.
- p95 read API latency below 300 ms under normal load; degraded features fail independently.
- Recovery point objective at most 5 minutes and recovery time objective at most 60 minutes for core identity and communication data.

## Bounded Domains

- Identity and access: accounts, passkeys, MFA, sessions, devices, recovery.
- Relationship graph: people, reciprocal edges, visibility, family topology, imports.
- Communication: direct messages, circles, calls, reactions, receipts, moderation.
- Life record: diary, timeline, milestones, goals, memories, settlements.
- Document vault: uploads, classification, versions, OCR, retention, sharing, legal holds.
- Health: diagnostic reports, normalized observations, trends, provenance, safe guidance.
- Wealth: transactions, budgets, goals, projections, consented provider connections.
- Trust and safety: blocks, reports, emergency access, abuse prevention, policy enforcement.
- Agent platform: plans, permissions, approvals, executions, evidence, audit, rollback.

Keep these as modular-monolith boundaries initially. Extract a service only when scaling, deployment cadence, failure isolation, or regulatory ownership provides measurable benefit.

## Runtime Architecture

1. Edge: CDN, DDoS protection, WAF, bot controls, TLS, rate limits.
2. API gateway/BFF: authentication, coarse rate limiting, request size limits, correlation IDs, API versioning.
3. Stateless application replicas: Spring Boot domain modules and realtime gateway.
4. Durable work queue: document processing, notifications, media transforms, AI jobs, exports, and deletion workflows.
5. AI orchestration service: policy evaluation, retrieval, model routing, structured outputs, safety checks, and evaluation telemetry.
6. PostgreSQL: system of record with read replicas, connection pooling, PITR, partitioning for high-volume event tables, and row-level ownership enforced in services.
7. Redis-compatible cache: ephemeral sessions, rate-limit counters, presence, idempotency, and short-lived query caching; never the only copy of user data.
8. Object storage: encrypted private buckets, quarantined uploads, clean objects, derived previews, versioning, lifecycle rules, and signed short-lived access.
9. Search: permission-filtered indexing for global search; database search remains source of truth until scale requires OpenSearch.
10. Observability: structured logs without sensitive payloads, metrics, traces, security events, SLOs, and audited administrator access.

## Agentic AI Safety Model

### Action Levels

- L0 Read-only: summarize, classify, extract, search, explain. Explicit purpose and scoped data access are still required.
- L1 Draft: prepare a message, task, budget, relationship suggestion, or care question. User reviews before execution.
- L2 Reversible action: organize files, create reminders, categorize transactions, or update metadata. Requires approval by default and provides undo.
- L3 External or sensitive action: send messages, share documents, change permissions, contact providers, or alter health/financial records. Just-in-time approval is mandatory.
- L4 Prohibited autonomy: medical diagnosis, medication changes, financial trades, identity/security setting changes, deletion of protected records, or irreversible legal decisions. AI may explain options but cannot execute.

### Required Controls

- Per-capability consent, least-privilege scopes, expiry, and revocation.
- Policy enforcement before planning, before tool execution, and before result persistence.
- Structured tool schemas; no arbitrary shell, SQL, URL, or file-system access from a model.
- Idempotency keys and bounded retries for every side effect.
- Evidence links and confidence for extracted or inferred information.
- Prompt-injection isolation: documents and messages are untrusted data, never instructions.
- Model/data residency routing by sensitivity and user region.
- Complete action ledger containing actor, model/policy version, purpose, scopes, approvals, tool calls, outcome, and timestamps without storing unnecessary raw prompts.
- Offline evaluation, red-team suites, canary releases, kill switches, cost budgets, and drift monitoring.

## Security Architecture

- Phishing-resistant passkeys plus optional TOTP; short-lived access tokens and rotating refresh tokens bound to sessions.
- Authorization checks at object and relationship level; deny by default and test cross-user access for every endpoint.
- Envelope encryption with cloud KMS; separate keys for database, object storage, backups, and highly sensitive document classes.
- TLS in transit and service identity for internal calls.
- Quarantine all uploads. Verify extension, declared MIME, magic bytes, archive contents, decompression ratio, parser safety, malware scan, and content policy before promotion to clean storage.
- Sandboxed OCR/media conversion with no outbound network, CPU/memory/time limits, and patched parsers.
- Secrets only in a secret manager; dependency pinning, SBOM, signed images, provenance, SAST, DAST, secret scanning, and container scanning in CI.
- Immutable security audit trail, anomaly detection, incident runbooks, breach notification process, and regular restore/penetration exercises.
- Data minimization, retention schedules, self-service export/deletion, consent history, legal basis, regional residency, and child/safeguarding controls before broad launch.

See `threat-model.md` for abuse cases and launch gates.

## Data and API Evolution

- PostgreSQL Flyway migrations are backward compatible and expand/migrate/contract.
- Public APIs are versioned, paginated, bounded, idempotent where applicable, and described by OpenAPI.
- Use UUIDv7 or another globally sortable opaque identifier before cross-region write distribution.
- Introduce outbox events for reliable asynchronous work; consumers are idempotent and schema-versioned.
- Partition messages, audit events, notifications, and AI action events by time and/or tenant ownership when measured volume requires it.
- Maintain provenance for every normalized health or financial observation.

## Ten-Year Capability Roadmap

### Foundation (now)

- Reliable identity, durable PostgreSQL, validation, upload quarantine, global search, consistent web/mobile UX, audit, backups, and SLOs.
- Governed AI action ledger with consent and approval primitives.
- Document ingestion with OCR/extraction provenance and health trend normalization.

### Assistance

- Relationship maintenance suggestions, duplicate resolution, memory organization, goal planning, document reminders, and household coordination.
- Personal knowledge retrieval across authorized content with citations.
- Health and wealth insights framed as education and questions for qualified professionals, never diagnosis or guaranteed outcomes.

### Delegation

- User-defined routines with explicit scopes, budgets, schedules, approval thresholds, and undo.
- Multi-person workflows require consent from every affected account and never infer private relationships for disclosure.

### Ecosystem

- Stable partner APIs, consented provider connections, regional deployments, enterprise/family administration, accessibility localization, and independently audited security/privacy controls.

## Delivery Gates

A feature is not complete until API authorization and validation, web/mobile parity, accessibility, telemetry, tests, migration/rollback, threat-model update, and operational documentation are complete. Production launch additionally requires external penetration testing, privacy/legal review, backup restore proof, capacity/load proof, incident exercises, and signed release artifacts.

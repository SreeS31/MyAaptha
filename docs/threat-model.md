# MyAaptha Threat Model

## Protected Assets

Account identity, relationship graph, private messages, circles, media, documents, health observations, financial data, precise contact information, sessions, encryption keys, AI permissions, and audit evidence.

## Trust Boundaries

Browser/mobile device; public edge; application API; internal AI service; background workers; PostgreSQL; cache; quarantine and clean object stores; model providers; notification/contact providers; administrator tooling.

## Primary Threats and Required Mitigations

| Threat | Required controls | Verification |
| --- | --- | --- |
| Broken object authorization | Ownership/relationship policy on every object lookup; deny by default | Cross-account integration tests for every resource type |
| Account takeover | Passkeys/MFA, refresh rotation, device sessions, risk alerts, rate limits | Auth abuse tests and session-revocation drills |
| Malicious upload | Quarantine, signature/MIME checks, archive limits, malware scan, sandbox transforms | Polyglot, EICAR, archive bomb, parser timeout test corpus |
| Stored XSS/content injection | Encode by context, sanitize supported rich content, strict CSP | Browser security tests and DAST |
| Prompt injection | Treat retrieved content as data, fixed tools, policy checks, egress deny, output validation | Adversarial document/message evaluation suite |
| AI overreach | Capability scopes, L0-L4 policy, approval, idempotency, rollback, kill switch | Policy unit tests and execution-ledger review |
| Sensitive-data leakage | Data minimization, redaction, scoped retrieval, private model endpoints, no default training | DLP tests and provider-contract review |
| Enumeration/scraping | Permission-filtered search, response normalization, quotas, bot detection | Load and abuse tests |
| Message spam/harassment | Rate limits, blocks, reports, reputation signals, moderation queues | Abuse simulations and response SLOs |
| Insider/admin abuse | Just-in-time privileged access, dual approval, immutable audit, no direct production DB access | Quarterly access review and alert drills |
| Supply-chain compromise | Locked dependencies, SBOM, provenance, signed images, scanning, protected branches | CI release policy enforcement |
| Data loss/ransomware | PITR, immutable cross-account backups, versioned objects, restore exercises | Scheduled restore evidence |
| Cross-region/privacy violation | Residency policy, purpose/consent ledger, retention/deletion workflows | Privacy tests and legal launch review |

## AI-Specific Rules

1. User content can influence an answer but cannot grant permissions or change system policy.
2. Models never receive secrets, raw refresh tokens, unrestricted database access, or cloud credentials.
3. Health and wealth recommendations must show provenance, uncertainty, and professional-help boundaries.
4. Any action affecting another person requires explicit target authorization and appropriate user approval.
5. High-impact actions remain unavailable even when a prompt requests them.

## Production Security Gates

- Independent penetration test with critical/high findings closed.
- OWASP ASVS level-2 baseline mapped and evidenced; higher controls for health/financial/admin functions.
- Cloud IAM, network, KMS, backup, and logging review by a second qualified engineer.
- Successful regional backup restore and failover exercise.
- Incident response, data breach, key compromise, malicious upload, and AI kill-switch exercises.
- Privacy impact assessment, retention matrix, child-safety decision, and applicable jurisdiction review.

Security is risk reduction, not a claim of “100% secure.” Residual risks must have an owner, severity, mitigation date, and acceptance record.

# Discovery data review — 17 October 2026

This completes the **review** scope of M03.5. No user, relationship, nomination or message records were deleted or changed.

The local preview aggregate-only audit found:

| Metric | Count |
|---|---:|
| Accounts matching the `memory-` plus eight hexadecimal characters fixture pattern | 29 |
| Distinct nominated role-model accounts | 11 |
| Nominated role-model accounts matching that fixture pattern | 11 |

The query used `BEGIN READ ONLY`, a ten-second statement timeout and `ROLLBACK`. It returned counts only, with no account identifiers, names, contact fields or credentials. Repeatable SQL is `infrastructure/audit-discovery.sql`; the local result is `.tools/launch-board/discovery-audit.log`.

## Why the screenshot showed those cards

`frontend/nextjs-app/integration/core-services.spec.ts` creates accounts named `memory-${randomUUID().slice(0,8)}`, nominates one as a role model and exercises following. It disposes its API context but does not remove those account/nomination fixtures afterwards. `TrustService.roleModels` lists distinct role-model nominations across accounts and uses the username when the profile has no display name. Thus retained integration fixtures can appear as those generated-looking cards.

This is strong evidence explaining the screenshot and local nominated-account pattern; a matching name alone is not an approved basis for deleting an account. A role-model nomination is not a platform identity verification or endorsement.

## Handover actions

- Keep destructive cleanup separate from review: identify the exact approved fixture records, preserve any needed data and apply reviewed cleanup only to that set.
- Run future UI fixture creation against a dedicated disposable preview database rather than the account dataset used for user demonstrations.
- If broader public discovery policy is changed, define consent, blocked-account behavior and nomination eligibility explicitly, then test it across clients. This review does not silently change that policy.

The board marks the review complete and does not claim fixture cleanup or a new discovery policy was implemented.

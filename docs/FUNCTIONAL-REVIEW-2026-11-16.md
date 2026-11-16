# MyAaptha functional review — 16 November 2026

Reviewed canonical application source at `12d737525b9d3de503ed771eef3ed4a8bf108582` on `feature/launch-readiness-20261027`. This review distinguishes automated coverage from real provider and device acceptance.

## Release and live state

- [Source CI](https://github.com/SreeS31/MyAaptha/actions/runs/43680656835) and [beta validation, runtime checks and image security gates](https://github.com/SreeS31/MyAaptha/actions/runs/43680692843) completed successfully for this exact commit.
- GCP readback: project `project-5c36c021-87c7-4cfc-833`, VM `myaaptha-beta`, zone `asia-south1-a`, status `RUNNING`, public IP `35.244.31.192`.
- Live HTTPS API health returned `UP`. Desktop and mobile public navigation, accessibility, viewport and browser-error checks passed (two scenarios covering `/`, `/auth`, `/recover-account`, `/verify-phone`). These checks do not authenticate or modify customer records.
- Live CSS does not contain the current community UI markers. The latest frontend has **not** been deployed by this review.

## Fresh local checks

| Component | Evidence and scope |
|---|---|
| Infrastructure | 105 unittest checks passed; release validation, beta deployment tooling, recovery policy, launch board and related contracts. |
| AI | 11 pytest checks passed; service behavior under test configuration, not real model/provider acceptance. |
| Web unit | 23 checks passed; contacts import, message pagination, call resource cleanup, upload security and related contracts. |
| Web build | Production compilation, type checks and bundle generation passed. Existing image-optimization lint warnings remain. |
| Live public web | Both desktop and mobile read-only scenarios passed. |
| Native | Flutter analysis reported no issues. Widget/unit suite passed: 105 tests, two skips (live account sync and renewals require an integration backend). Physical-device/provider acceptance remains separate. |
| Web browser | Initial production run: 28 passed, two typography timeouts. After the test-harness fix, all six desktop/mobile public accessibility and typography checks passed. |
| Backend recheck | All 14 checks passed across the five affected application test classes and the new cross-connection constraint regression, with zero failures/errors/skips. A full CI rerun is required for the final change. |

Test logs are under ignored `.tools/full-review-*-20261116.log`; they are local evidence and are not shipped as application assets.

The first full production-browser run passed 28 scenarios and timed out on two public typography scenarios. A single-worker retry passed desktop but timed out on mobile while inspecting the phone picker's large button list. The regression now collects computed styles for visible elements in one browser call per element type, preserving font-size/family assertions while avoiding a protocol round trip for every hidden picker option. This is a test-harness change; application behavior is unchanged.

The full backend run executed 263 tests: three failures, eight errors and three skips. The failing cases traced to H2 2.4.240's `ConditionInConstantSet` retaining a closed connection's comparator, matching [upstream issue 4308](https://github.com/h2database/h2database/issues/4308). H2 is test-scoped and now uses 2.5.252; the [upstream release notes](https://github.com/h2database/h2database/releases) record the constraint fix in 2.5.250 and subsequent fixes in 2.5.252. PostgreSQL production configuration is unchanged. A focused regression closes the schema-creating connection, then verifies another connection can insert a permitted value and still rejects an invalid value. This regression reproduced the bug on 2.4.240 and passed on 2.5.252. The five affected application classes also passed in the final sequential run (14 total checks including the regression). The initial full backend run must not be described as passing; full final-commit CI remains required.

## Functional coverage and acceptance limits

The backend/web/native suites and existing launch board cover identity and sessions; profiles/settings; relationships and discovery; contact import; timeline; circles; messaging/calls; diary/feed/stories; health; finance; trust/emergency access; AI consent/controls; notifications; uploads/security reports; and operational release tooling. Coverage is not proof that every workflow works with every live provider or physical device.

The [18-module status](launch-board/STATUS-2026-11-09.md) still records 29 pending launch tasks. Real SMS/recovery delivery, contacts OAuth, notification delivery, call relay acceptance, external AI, physical Android/iOS distribution, independent privacy/security review, representative authenticated capacity and recovery acceptance remain separate gates. This review does not close them.

Docker Desktop's Linux engine is unavailable on this host. Fresh local PostgreSQL/Redis/antivirus integration and container smoke checks therefore could not run. The linked successful CI is separate evidence for the reviewed commit. Do not point local integration fixtures at the live beta.

## Pending GCP frontend update

The scanned frontend image for the reviewed commit is:

```text
ghcr.io/srees31/myaaptha-frontend@sha256:b2bfbbccd9a86f49c2711776564e9e0ad3a2afe37ba9d4a2fbc8093e9bbdc56c
```

The connected GCP command tool explicitly rejected `gcloud compute ssh` as unsupported. The local portable CLI has no active authenticated account. No cloud rollout, restart or database change was performed.

From an authenticated checkout on a machine with `gcloud`, upload the existing guarded updater and run it on the beta VM:

```bash
gcloud compute scp infrastructure/update_beta_frontend.py myaaptha-beta:/tmp/myaaptha-update-frontend-20261116.py --zone=asia-south1-a --project=project-5c36c021-87c7-4cfc-833 --tunnel-through-iap
gcloud compute ssh myaaptha-beta --zone=asia-south1-a --project=project-5c36c021-87c7-4cfc-833 --tunnel-through-iap --command='sudo python3 /tmp/myaaptha-update-frontend-20261116.py --image ghcr.io/srees31/myaaptha-frontend@sha256:b2bfbbccd9a86f49c2711776564e9e0ad3a2afe37ba9d4a2fbc8093e9bbdc56c'
```

The updater verifies the project/instance identity, pulls the immutable image, preserves the previous protected configuration, updates only the frontend, checks HTTPS and API health, and restores the previous frontend configuration if verification fails. After rollout, rerun the live browser checks and verify the running container image plus community navigation with a synthetic account. Public landing checks alone do not exercise authenticated community functions.

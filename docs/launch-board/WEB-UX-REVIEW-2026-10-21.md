# Web interface and form review ? 21 October 2026

## Implemented refinements

A final shared stylesheet gives all application routes consistent neutral surfaces, bordered white page headers, clear teal primary actions, restrained secondary/destructive treatments, aligned field labels and consistent form controls. Existing compact layouts, functional page grids, storage usage ring and semantic timeline event colours are retained. Mobile text-entry controls use 16px text and larger touch targets. Read-only, disabled, focused and invalid controls have distinct treatments. Dialogs use a consistent border, backdrop and wrapping action footer. Reduced-motion preferences are respected.

Workspace navigation now includes a skip link, correct mobile expanded-state reporting, an inert closed mobile sidebar, focus cycling and Escape-to-menu behavior. Opening navigation locks background scrolling and closing restores its prior value. Profile photo/gallery file inputs remain keyboard focusable through visibly focused upload labels. Authentication status is announced politely, and sign-in/registration forms expose busy state.

## Review scope

The existing source contains 28 distinct web routes, including a parameterized person route. The baseline desktop and phone-browser route review passed before modification. Expanded review includes public registration/recovery/verification, five profile section editors and photo controls, timeline and circle dialogs, multiple health measurements, disclosure forms and administrator settings/help panels. Reviews check viewport fit, typography, accessible control names, contrast, keyboard access and cancellation/required-field behavior. Screenshot and JSON findings are retained under `.tools/ui-review-current` and `.tools/ui-forms-current`; the pre-change snapshots are preserved under `.tools/ui-review-baseline-20261020`.

These browser checks use synthetic local accounts and selected representative states. They do not establish physical-device or screen-reader acceptance, provider-backed workflows, populated-data coverage for every combination, or complete WCAG certification. No API payload/schema or native Flutter screen changed in this web styling batch.

## Verification

Final verification passed on the assembled production web build. Source changes: `app/professional.css`, root layout, WorkspaceShell, profile and authentication pages. Existing design-system checks were expanded and a professional-forms integration scenario added.

## Issues found by expanded verification

The first updated-build review found two pre-existing functional presentation problems beyond styling. Node and Chromium Intl region names differed for four country entries, causing React hydration error 418 on recovery and phone verification. The phone picker now uses a single checked-in English country inventory and deterministic sorting. The expanded manual health form overflowed on desktop because its display:contents fieldset changed the grid parent relationship. Its heading, notes, measurement group and save action now span the form grid; measurement inputs have persistent labels and shrink-safe columns.

The initial updated suite recorded four failures and two passes: both route reviews caught country hydration errors; desktop expanded forms caught health overflow; an existing desktop primary-action test hit a five-second wait before the health empty-state action was available. The latter now allows 15 seconds for loaded data. A separate warm dashboard probe found no failed API requests or network-load error. All reviewed default route states had no horizontal overflow and no selected contrast/control-name violations. These findings are retained rather than reported as a passing final run.

The keyboard upload pattern was also applied to diary attachments and person photo/memory uploads. Expanded person-detail panels, finance SMS mode and managed/deceased-person form variants are included in the final browser review. No external delivery is triggered by these form inspections. An intermediate build was deliberately stopped before completion to include the additional upload controls in one final candidate.

## Final verified results

Six targeted scenarios passed in both browser projects: all-route review, expanded forms/navigation, primary-action hover/focus, profile/API persistence, health error/retry and administrator upload-level draft. This is 12 distinct scenario/project results, assembled from the final logs listed below; earlier failed/partial runs are not added to the total.

- All 28 distinct routes passed on each layout (31 observations per layout including administrator variants): no runtime page errors, horizontal overflow or selected control-name/contrast violations.
- All 27 expanded form states per layout passed. Administrator upload-level draft checks passed separately on both layouts, without saving global settings. Fresh synthetic administrator accounts were restored to ordinary roles.
- Profile cancellation/save and cross-session section merging passed. Health validation, retained draft/retry, duplicate-submit prevention and multi-measurement persistence passed.
- Keyboard checks passed for mobile menu focus/Escape/inert state, skip link and upload inputs. Existing compact/wave timeline and storage-ring behaviour passed profile-overview regressions.
- Production build/type validation passed. Existing image/hook lint warnings remain; no new build error was suppressed. Local web/API/helper/board endpoints returned HTTP 200.
- Final API/debug-APK/assembled-web fingerprints match the refreshed identity record; releaseApproved remains false. An initial fingerprint attempt before standalone assets were assembled correctly reported incomplete prerequisites and was replaced only after assembly completed.

Final logs under `.tools`: `ui-final-verification-20261021.log` (three completed desktop scenarios before an expanded-disclosure test wait was interrupted), `ui-final-desktop-forms-20261021.log` (two desktop scenarios), `ui-final-admin-desktop-20261021.log` (one desktop scenario), `ui-final-mobile-20261021.log` (six phone-browser scenarios), `ui-complete-build-20261021.log`, `ui-artifact-verify-20261021.log` and `ui-board-20261021.log`. The disclosure test now explicitly opens the loaded person form and closes its country-picker menu before interacting, with bounded waits; it does not bypass application checks.

[Machine-readable verification summary](web-ux-verification-2026-10-21.json). The launch board records this local UI evidence under M16.6; its selected-staging acceptance requirement remains open. No launch closure count changed.

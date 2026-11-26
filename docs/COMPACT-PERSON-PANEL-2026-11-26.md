# Compact person information panel

The relationship-tree person panel now uses a compact initials header and aligned label/value rows. Labels are smaller and muted; saved values are stronger, and missing values are quieter. The same hierarchy is applied to the native mobile card. Phone, email, organization, relationship, tree membership and editing actions are preserved.

This is a presentation change; no API, schema, contact access or graph behavior changes.

Validation: production web build; desktop/mobile interaction checks and browser-computed typography (11px labels, 14px values); three targeted native widget checks. Exact-commit CI passed 323 backend tests (one skipped), 102 browser scenarios, 30 frontend unit checks, native analysis and 141 native tests (two skipped), security checks, production smoke testing and all release-image checks.

Published source `d55f9a82b0d117dd032d15c135fb21990ddc5f97`, tag `beta-20261126-person-panel-r1`. [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45859958510) and [release images](https://github.com/SreeS31/MyAaptha/actions/runs/45859958480).

Deployed to the existing [GCP beta](https://35-244-31-192.sslip.io/relationship-tree?view=saved) with immutable image digests recorded in `infrastructure/production/person-panel-images-20261126.json`. HTTPS/API health is UP; schema remains 81. Google contact import and authenticated call-relay configuration were preserved. Database backup `/opt/myaaptha-beta/runtime/release-backups/20261126T164318427960Z.dump` was restored into a disposable database and its user count verified before deployment.

Six live desktop/mobile scenarios passed, including person details, graph interactions, accessibility and actual font-size checks. All four temporary accounts and all associated trees/contacts were removed; all 15 cleanup counts are zero. Existing user data was not rewritten. Android beta package built successfully; physical-device installation remains unverified.

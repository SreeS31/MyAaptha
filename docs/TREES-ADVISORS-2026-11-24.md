# Reviewed relationship trees and private advisors - 24 November 2026

## Relationship trees

The Suggested trees tab analyzes all of the signed-in user's saved contacts. Organization, explicit contact labels, private circle membership, family words and name tags provide explainable proposals. Shared surnames and email domains are weak clues, never proof of kinship or employment. No external AI service receives these contacts in this implementation. Groups need at least three contact nodes; the You root does not count. Proposals are paginated without a total tree quota.

Users review names, relationship labels and parent connections, add contacts or manual people, remove nodes, dismiss/restore suggestions and explicitly approve saving. My trees supports multiple independent manual/suggested trees and versioned editing. Saving never creates public accounts, messaging memberships or invitations. Draft/saved payloads use the existing field encryption; ownership applies to every read and mutation. Existing Family tree and Chain explorer remain available.

## Advisors and well-wishers

Private lists support MyAaptha members, imported private contacts and external HTTPS profile cards. Twelve initial categories include Personal, Health & fitness, Wealth, Education & career, Law, Sports and Arts. Users can create additional categories and put a person in several categories. There is no total advisor quota; lists and searches are paginated. These lists do not grant Trust/Star/emergency access or publish an endorsement.

The Posts view follows selected MyAaptha members, filtered by category, with existing like, comment, reaction, save, collection, forwarding and reporting actions. New idempotent reposts retain attribution and original audience checks, including after access revocation. Private diary entries cannot be reposted. Users can pause following without deleting a card. External profile cards are reference links; this release does not import Instagram/other provider feeds.

Web, Flutter and APIs share categories, versioned advisor records and feed cursors. Migrations 78 and 79 are additive. No new public ports, OAuth scopes or external AI credentials are required.

## Pending earlier scope

Earlier deployed work covers interests/circle discovery, contact sign-in and reviewed import, circle trees, menu/copy cleanup, circle administration, chat workspace controls, personal/community social additions, and finance statement imports/reports. Google Contacts is configured on beta; Microsoft still needs an owner-provided provider application. Real phone acceptance remains outstanding.

Full Instagram/WhatsApp parity remains incomplete as detailed in INSTAGRAM-WHATSAPP-PARITY-2026-11-23.md: message E2EE/device key recovery, background platform calling, large-call media infrastructure, live broadcasts, communities/channels, view-once media, multi-attachment editors and other rows are not supplied by ordinary messaging or TURN. Commercial tools remain deferred. Call-frequency highlighting and additional contact intelligence are not claimed by this release.

## Validation

Targeted browser checks: 10 desktop/mobile cases passed, including accessibility, viewport fit, original family/chain views, reviewed node editing and advisor post actions. Native targeted widget tests: 8 passed; native analysis clean. A 2,000-contact integration case covers scanning every contact and owner isolation. Final CI, immutable images and deployment evidence will be recorded after validation.

## Deployment evidence

Application source `3a71924ca8221f0ca28fb2c9cf953d7c33ba06ef`, tag `beta-20261124-trees-advisors-r1`, is deployed to the existing GCP beta VM. [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45361173824) and [image validation/security scans](https://github.com/SreeS31/MyAaptha/actions/runs/45361173853) passed. CI completed 314 backend tests (zero failures/errors, one skip), 88 browser scenarios, 26 web unit tests and 131 native tests (two expected skips); native analysis is clean.

Both additive migrations are applied, schema 79. Exact running image digests and HTTPS health UP were verified. Fresh backup `/opt/myaaptha-beta/runtime/release-backups/20261124T104440408086Z.dump` was restored into a disposable database and its user count verified before migration. Existing Google Contacts configuration, authenticated TURN and the beta overlay were preserved. Microsoft remains unconfigured.

Live API checks passed for followed/category-filtered posts, private-post exclusion, likes, saves, comments, idempotent reposts, owner isolation and pausing follows. The two synthetic social posts were removed through their author's API. Live browser and fixture cleanup results are recorded below when complete.

Matching Android debug test build: `.tools/preview/MyAaptha-beta-trees-advisors-20261124.apk`, SHA-256 `a91ae7428149c76fd736bac4473e73359a5b5775d4c8207877437c6f5ae1eb1b`. This is a test APK, not an app-store release. Physical-device acceptance is still required.

Final live browser validation: four desktop/mobile scenarios passed, covering reviewed suggestions, removing a node and saving three people, reopening a saved tree, private contact/profile advisor cards, categories, viewport fit and public navigation/accessibility. One initial desktop harness assertion timed out during an asynchronous save; it now waits explicitly for the response and dialog completion. The final rerun passed both layouts.

Six exact synthetic identities, including the interrupted attempt, were removed with guarded cleanup. All remaining synthetic account, contact, circle, call, call-member, call-signal, finance, active-media, tree, advisor and repost counts are zero. No customer contacts were used as test fixtures or changed by the harness. Deployment evidence and immutable digests are in `infrastructure/production/trees-advisors-images-20261124.json`.

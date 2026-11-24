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

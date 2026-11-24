# Restored tree views and project inputs

The original confirmed Family tree (Modern, Heritage and Compact) and right-growing Chain explorer remain intact. Suggested trees and My trees previously used a separate plain list. Their review editor now offers Modern, Heritage, Compact and Right-growing diagrams on web and native mobile, with connectors, expand/reset controls, bounded incremental rendering and node selection.

Men use blue, women pink, other/unspecified grey. Filled circle controls indicate children; hollow circles indicate an end node. Gender is explicitly editable and saved in the private tree payload. Old tree data remains compatible with unspecified gender; names do not determine gender. Editing connections still requires review before saving and does not invite contacts to messaging circles.

## Inputs needed

Web: `/project-inputs`, under **Administration → Inputs needed**. Native: **Account & tools → Inputs needed**, visible to administrators. API: `GET /api/admin/project-inputs`, `POST /api/admin/project-inputs/{key}`. Ordinary users receive 403. This is a shared project setup board, not a public social page.

The board keeps Meta, Firebase, APNs, encryption, physical-device acceptance and the remaining personal/community parity backlog pending. Provider status is unknown until supplied; the page does not report a configured service based on an unchecked declaration. Drafts persist across devices. Ready for review records the owner's request for a subsequent implementation pass; it does not activate providers, enable E2EE, deploy changes or run an unattended coding agent.

Only public IDs, enumerated decisions and Google Secret Manager references are accepted. Put credentials in the project's Secret Manager, then supply `projects/PROJECT/secrets/NAME/versions/latest`; do not paste JSON credentials, signing keys or access tokens into these fields. The board's payload is protected by the existing field-encryption configuration. No credential files are committed. Optimistic versions reject stale updates from another device or administrator.

The next implementation pass can read the structured board through the administrator API. A ready status is input for work, not proof of provider permission approval or completed acceptance testing. Full Instagram/WhatsApp parity remains incomplete; commercial tools remain deferred. See [the feature audit](INSTAGRAM-WHATSAPP-PARITY-2026-11-23.md).

## Validation and release

Release evidence will be recorded after CI, image validation and beta verification complete. Physical Android/iPhone acceptance and provider activation are outside this UI restoration release.

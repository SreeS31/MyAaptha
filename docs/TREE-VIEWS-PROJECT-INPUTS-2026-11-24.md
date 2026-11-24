# Restored tree views and project inputs

The original confirmed Family tree (Modern, Heritage and Compact) and right-growing Chain explorer remain intact. Suggested trees and My trees previously used a separate plain list. Their review editor now offers Modern, Heritage, Compact and Right-growing diagrams on web and native mobile, with connectors, expand/reset controls, bounded incremental rendering and node selection. Circular branch controls also override the shared button styling in the original Family tree and Chain explorer.

Men use blue, women pink, other/unspecified grey. Filled circle controls indicate children; hollow circles indicate an end node. Gender is explicitly editable and saved in the private tree payload. Old tree data remains compatible with unspecified gender; names do not determine gender. Editing connections still requires review before saving and does not invite contacts to messaging circles.

## Inputs needed

Web: `/project-inputs`, under **Administration → Inputs needed**. Native: **Account & tools → Inputs needed**, visible to administrators. API: `GET /api/admin/project-inputs`, `POST /api/admin/project-inputs/{key}`. Ordinary users receive 403. This is a shared project setup board, not a public social page.

The board keeps Meta, Firebase, APNs, encryption, physical-device acceptance and the remaining personal/community parity backlog pending. Provider status is unknown until supplied; the page does not report a configured service based on an unchecked declaration. Drafts persist across devices. Ready for review records the owner's request for a subsequent implementation pass; it does not activate providers, enable E2EE, deploy changes or run an unattended coding agent.

Only public IDs, enumerated decisions and Google Secret Manager references are accepted. Put credentials in the project's Secret Manager, then supply `projects/PROJECT/secrets/NAME/versions/latest`; do not paste JSON credentials, signing keys or access tokens into these fields. The board's payload is protected by the existing field-encryption configuration. No credential files are committed. Optimistic versions reject stale updates from another device or administrator.

The next implementation pass can read the structured board through the administrator API. The guarded read-only `infrastructure/read_project_inputs.py` helper also reads this board on the beta VM, decrypting only the board metadata in memory; it never retrieves referenced provider secrets. Encrypted-board reads require Python `cryptography` on that VM. A ready status is input for work, not proof of provider permission approval or completed acceptance testing. Full Instagram/WhatsApp parity remains incomplete; commercial tools remain deferred. See [the feature audit](INSTAGRAM-WHATSAPP-PARITY-2026-11-23.md).

## Validation and release

Source: `40d0f2430eecb22a5e379451237e153441b89526`, tag `beta-20261124-tree-views-inputs-r4`.

- [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45462088742) and [image validation/scans](https://github.com/SreeS31/MyAaptha/actions/runs/45462109673) passed on this exact source.
- Backend: 321 tests, zero failures/errors, one skip. Frontend: 96 browser scenarios and 26 unit tests. Native: clean analysis, 138 passed and two expected skips.
- Desktop/mobile browser coverage verifies the original Family/Chain views, all four private-tree layouts, explicit gender persistence, review/save behavior, accessibility and project-input draft persistence. Branch circle geometry was additionally verified on both viewport types.
- The read-only setup-board helper was verified on beta. Its encrypted metadata round-trip and tamper rejection were tested with synthetic in-memory values, without writing project inputs or retrieving provider secrets.
- Matching Android debug APK: `.tools/preview/MyAaptha-beta-tree-views-inputs-20261124.apk`, SHA-256 `9b070de7c9c9e041b11efda63ffd98df0a11555626f1babc314d98e16a4658b6`.

Physical Android/iPhone acceptance and provider activation remain pending. Deployment and live verification are recorded in `infrastructure/production/tree-views-inputs-images-20261124.json`.

Beta deployment verified: exact validated image digests, HTTPS/API health UP and schema 81. Backup `/opt/myaaptha-beta/runtime/release-backups/20261124T185017486068Z.dump` was restored into a disposable database before rollout. Four final live desktop/mobile scenarios passed. All four synthetic accounts from this work and their contacts/trees were removed; both guarded cleanup audits returned 15 zero counts. Google Contacts and authenticated TURN remain configured. Provider setup and full Instagram/WhatsApp parity remain pending in the input board.

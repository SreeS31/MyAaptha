# WhatsApp groups to reviewed relationship trees

Personal WhatsApp account group discovery is not connected. Meta's [Groups API](https://developers.facebook.com/documentation/business-messaging/whatsapp/groups) supports eligible business-created groups; it is not a personal-account permission flow for enumerating existing groups and members.

The Relationships page adds a **WhatsApp groups** tab. Supply a group name and a member list (one person per line), or a WhatsApp plain-text chat export. The filename can suggest the group name, which must be reviewed. Chat exports detect timestamped speakers only: silent members can be missing, former members can appear, equal display names are deduplicated, and unrecognized/localized timestamp formats can yield no names. Users can add, edit, remove and connect nodes before explicitly reviewing and saving a tree with at least three people.

Chat parsing runs on the user's device. Raw messages are not sent to an import API or stored as chat history. Only reviewed names, roles and tree connections use the existing encrypted, owner-scoped relationship-tree API. Everyone starts as Member with unspecified gender; co-membership is not evidence of family ties. Saving creates no invitations, messaging memberships or WhatsApp actions. Saved trees are available through the shared API and existing native My trees view; native direct WhatsApp import controls are not included.

Input is bounded to a 5 MB text file and the existing 50,000-node tree limit. No QR pairing, account scraping, credentials, unofficial account connector or background synchronization is introduced. No real user WhatsApp account has been accessed. The user must supply the group data to import it.

Released source `2c80a1d00f1876f24d6d8761c484a22af9fb95cf`, tag `beta-20261125-whatsapp-trees-r2`. [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45641129909) and [image validation](https://github.com/SreeS31/MyAaptha/actions/runs/45641129104) passed for the exact commit. All 102 browser scenarios passed without retries; 28 web unit tests passed. Backend: 322 tests, zero failures/errors, one skip. Native: clean analysis, 141 passed and two expected skips. Native source is unchanged; the existing Android beta build remains compatible. Physical device acceptance remains pending.

The first image-validation attempt found a mobile editor footer overlapping selectable nodes. The footer now stays in document flow. All six targeted desktop/mobile editor/import scenarios passed after the fix, followed by the full production release checks.

The [release manifest](../infrastructure/production/whatsapp-trees-images-20261125.json) records deployed immutable images, healthy HTTPS/API services and unchanged schema 81. Backup `/opt/myaaptha-beta/runtime/release-backups/20261125T151400988821Z.dump` was restored into a disposable database and user count verified before startup. Google Contacts and authenticated calling-relay configuration remain present.

Four live desktop/mobile scenarios passed: member-list import, explicit review, exact group-name persistence, three neutral Member nodes, saved-tree display through the shared API, viewport fit and public accessibility/navigation. Two synthetic accounts were removed under exact ID/username guards; all 15 scoped cleanup counts returned zero. No real WhatsApp account or group was accessed.

# WhatsApp groups to reviewed relationship trees

Personal WhatsApp account group discovery is not connected. Meta's [Groups API](https://developers.facebook.com/documentation/business-messaging/whatsapp/groups) supports eligible business-created groups; it is not a personal-account permission flow for enumerating existing groups and members.

The Relationships page adds a **WhatsApp groups** tab. Supply a group name and a member list (one person per line), or a WhatsApp plain-text chat export. The filename can suggest the group name, which must be reviewed. Chat exports detect timestamped speakers only: silent members can be missing, former members can appear, equal display names are deduplicated, and unrecognized/localized timestamp formats can yield no names. Users can add, edit, remove and connect nodes before explicitly reviewing and saving a tree with at least three people.

Chat parsing runs on the user's device. Raw messages are not sent to an import API or stored as chat history. Only reviewed names, roles and tree connections use the existing encrypted, owner-scoped relationship-tree API. Everyone starts as Member with unspecified gender; co-membership is not evidence of family ties. Saving creates no invitations, messaging memberships or WhatsApp actions. Saved trees are available through the shared API and existing native My trees view; native direct WhatsApp import controls are not included.

Input is bounded to a 5 MB text file and the existing 50,000-node tree limit. No QR pairing, account scraping, credentials, unofficial account connector or background synchronization is introduced. No real user WhatsApp account has been accessed. The user must supply the group data to import it.

Validation and release evidence will be added after checks complete.

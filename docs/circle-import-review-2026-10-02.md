# Circles and reviewed contact imports

Circle conversations now open in the shared chat workspace inside `/circles`, with a circle list on desktop and a back-to-list action on small screens. Dashboard and Relationship Tree remain separate pages.

File and device imports on web and Flutter now prepare a review before saving. Contacts with no usable phone number are skipped. A contact with multiple numbers retains its usable numbers even when another field is invalid. Eligible contacts start selected; users can deselect contacts and edit proposed circle names. Web previews use pages of 50 contacts, with selection retained across pages. The submission API accepts batches of at most 100 reviewed contacts and also checks phone eligibility on the server.

Suggestions use explicit labels, organization names, existing circle names and literal name text such as INCOIS, Inter and Padmashali. They do not infer community or other personal traits from someone's name. Suggestions currently work locally without an OpenAI key. They are not live model-generated suggestions. Reviewed circle lists remain private address-book associations, not chat membership, new relationships or invitations. Existing manual assignments are preserved on reimport.

Google and Microsoft callbacks now return contacts for review instead of saving them. Results remain owner-scoped, single-use and expiring. Live provider authorization still needs the local provider credentials; automated tests cover provider pagination, categories and no-save-before-review behavior with mocked provider responses.

## AI configuration

The health analyzer already maps its API key to `OPENAI_API_KEY`. No key was present in the current process, Windows user environment, or the encrypted local-preview key file during this work. Live OpenAI responses cannot be verified until a working key is supplied.

Run from the repository root in a local PowerShell terminal:

```powershell
.\infrastructure\configure-openai-local.ps1
.\infrastructure\stop-local.ps1
.\infrastructure\start-local.ps1 -SkipBuild
```

The configuration script reads hidden input and encrypts the saved key for the current Windows user. Do not put the key in browser/mobile code or commit it. The launcher now also loads an existing Windows user environment key. Health shows the missing configuration before upload and keeps manual measurements available.

Local test pages: http://localhost:3000/circles and http://localhost:3000/contacts.

This change does not certify million-account capacity, 5,000 concurrent users, or complete WhatsApp feature parity. Native source changes require a new mobile build for installed devices.

## Verification

- Production web build passed; existing image-optimization lint warnings remain.
- Eleven targeted backend tests passed (address book, OAuth imports, generic input validation). The four address-book tests were rerun successfully after adding protection for reviewed assignments.
- Five web contact-import unit tests passed.
- Flutter analysis reported no issues. Four Flutter tests passed, including skipping a phone-less contact and excluding an unchecked contact from a 201-contact device input.
- Desktop and mobile-browser flows passed: inline circle conversation, skipped invalid phones, default selection, deselection, edited circle, no save before submit, no automatic relationships, and clear missing-key status for health.
- A 2,007-contact desktop import passed, including existing-circle reuse, manual assignment preservation and idempotent retry. This is a functional bulk-import check, not a concurrent-user capacity test.
- Inspected final desktop circle-chat and mobile contact-preview screenshots. The mobile preview uses stacked cards to avoid squeezed phone/email columns.

Logs are under `.tools/circle-import-*`; final screenshots are under `.tools/preview/circles-inline-*` and `.tools/preview/contact-review-*`.

## OpenAI key follow-up

After the owner saved the key locally, the preview was restarted successfully. Both help AI and health AI report configured=true. A live application chat request fell back to HELP mode. Direct provider verification returned HTTP 429, error code `credit_balance_exhausted`, type `insufficient_quota`. Live AI remains blocked by the OpenAI account credit balance; no secret was printed or stored in this report. The owner must resolve API billing before a successful live-answer test can complete.

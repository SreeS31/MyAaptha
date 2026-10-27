# Private contacts and automatic circle organization

Web: http://localhost:3000/contacts. Mobile: **More → My contacts** or **Profile → My contacts**.

The owner chose a private address book, with relations added separately. Imports
therefore save contact records under the signed-in MyAaptha account. They do not
register accounts, create relations, send invitations or grant access to messages.
The same account can read these contacts and circle assignments on web and mobile.

## Import flow

1. Choose **Import all device contacts**, upload CSV/vCard, or enter an email and
   choose **Import Google Contacts** / **Import Outlook Contacts**.
2. Approve device access or provider sign-in when requested. An email address
   alone cannot authorize reading somebody's address book. MyAaptha does not ask
   for the email account's password.
3. Confirm saving the contacts. For automatic circle organization, enable
   sensitive-data AI processing in **AI controls** and leave **Automatically
   organize circles** enabled.
4. View the import result. Filter by circle or search by contact name. Use **Edit
   circles** to correct assignments; subsequent imports preserve manual choices.
5. Choose **Add as relation** separately when appropriate. That action can notify
   an existing member. Adding messaging-circle members remains a separate action.

Imports use batches of 100, with progress and a stop control on web/mobile. Device
and file imports no longer silently discard contacts beyond 2,000. The service
supports 50,000 private contacts per account, up to 20 numbers/emails/groups per
contact, and 20 MB contact files. Limits are reported, not silently truncated.
Completed batches remain saved if a later batch fails; an exact reimport is safe.
The duplicate identity combines normalized name and sorted phone/email values.
Renaming a contact or changing its phone/email set can create a separate entry;
this is not fuzzy person matching or continuous device synchronization.

All available phone numbers and email addresses are preserved, along with name,
organization and available group labels. Photos, postal addresses and notes are
not part of this import. iOS limited permission exposes only the selected subset;
grant full contact access in Settings if the user wants the full available list.
Browser contact access is a one-time picker on supported secure browsers. Other
browsers use provider sign-in or file upload. See the
[Contact Picker specification](https://www.w3.org/TR/contact-picker/).

## Circle behavior

The application AI service uses local, deterministic contact rules; importing and
grouping do not require an OpenAI key or send contacts to OpenAI. Only names,
organizations and group labels are sent to that service, never phone/email values.
Google user-defined group names and Outlook categories/folder names are preserved.
Recognized family names/labels suggest Family, an organization suggests its named
circle, and explicit friend/education hints provide corresponding groups. Without
a reliable signal, the contact goes to **Imported contacts**.

Matching owned circle names are reused ignoring case and repeated whitespace;
missing circles are created. Organization is limited to 500 owned circles. Circle
names are now unique per owner, rather than across all users. Imported contacts
are stored in private lists attached to those circles, separate from the actual
messaging member list. Other circle members cannot read these imported contacts.
The **Private contact list** link in web Circles and **Private contact lists** in
mobile Circles lead to this view. Correcting a list does not modify chat membership.

If AI is disabled, sensitive-data processing is not allowed, or the AI service is
unavailable, contacts are still saved. The import reports that grouping did not
finish; users can enable the setting and reimport or assign existing circles manually.
Classification can be wrong and should be reviewed before choosing relations.

## Enable email providers locally

Create OAuth web applications in the provider consoles. Google requires the People
API and read-only contacts scope. Microsoft requires delegated `Contacts.Read`.
Register these redirect URIs exactly:

- Google: `http://localhost:8080/api/contact-organizer/oauth/callback/google`
- Microsoft: `http://localhost:8080/api/contact-organizer/oauth/callback/microsoft`

Store each application's ID and secret locally, under your Windows account:

```powershell
powershell -ExecutionPolicy Bypass -File infrastructure/configure-contacts-local.ps1 -Provider google
powershell -ExecutionPolicy Bypass -File infrastructure/configure-contacts-local.ps1 -Provider microsoft
powershell -ExecutionPolicy Bypass -File infrastructure/stop-local.ps1
powershell -ExecutionPolicy Bypass -File infrastructure/start-local.ps1 -SkipBuild
```

The helper hides secret input and stores Windows-user-encrypted configuration in
ignored `.tools/preview/contact-providers.dpapi`. Existing environment variables
`GOOGLE_CONTACTS_CLIENT_ID`, `GOOGLE_CONTACTS_CLIENT_SECRET`,
`MICROSOFT_CONTACTS_CLIENT_ID`, and `MICROSOFT_CONTACTS_CLIENT_SECRET` take precedence.
No real provider credentials were supplied or created during development.
Unavailable provider buttons show that setup is required; file/device import is
independent of this configuration.

For a deployed app, set `MYAAPTHA_PUBLIC_API_BASE_URL` and
`MYAAPTHA_WEB_ORIGIN` to its public HTTPS origins and register the resulting
callback URIs. A physical phone cannot reach this computer through the phone's own
`localhost`; provider testing on physical devices needs an accessible HTTPS test
deployment. The Android emulator's API connection uses `10.0.2.2:8080`.

Google connections and groups are paginated. Outlook default contacts, nested
contact folders and categories are read with bounded pagination. This covers
saved contacts, not every sender in an inbox or an organization-wide directory.
Provider access tokens are used for this import only; no background authorization
or refresh token is retained. Reimport is user-initiated. OAuth pending state and
results currently live in one API process; multi-replica provider deployment needs
shared protected state or session affinity, and restarts require reconnecting.

Provider references: [Google groups](https://developers.google.com/people/api/rest/v1/contactGroups/list),
[Outlook folders](https://learn.microsoft.com/en-us/graph/api/user-list-contactfolders?view=graph-rest-1.0),
[Outlook child folders](https://learn.microsoft.com/en-us/graph/api/contactfolder-list-childfolders?view=graph-rest-1.0).

## Storage and validation

V59 adds owner-scoped private contacts and circle assignments. V60 removes the old
global circle-name uniqueness constraint and adds owner/name uniqueness. The local
preview was backed up at `.tools/preview/pre-address-book.dump` before migration.
Phone/email/organization/group payloads use the application's field-encryption
configuration; display names and grouping metadata remain searchable database
metadata. Local encryption follows the existing local settings. This is not
end-to-end encryption. Deleting private contacts does not alter the source address
book, separately created relations or circles.

Validation logs are under ignored `.tools/contacts-*`. Tests cover ownership,
consent, encrypted payloads, exact duplicates, pagination, existing circle reuse,
manual corrections, provider denial, Google pagination beyond 2,000 records,
parsing, whole-list batching and device-import confirmation. Live Google/Microsoft
authorization and physical Android/iOS permission behavior require configured
provider credentials and devices. iOS release compilation requires macOS/Xcode.

Final validation (26 September 2026):

- Full API verification and package: **120 tests passed**, zero failures/errors/skips,
  including real Redis. Three targeted provider tests also passed after adding the
  Outlook nested-folder case (Google pagination, Outlook folders, denial/replay).
- AI service: **11 tests passed**. Web unit tests: **11 passed**.
- Flutter: **22 tests passed**, analysis clean; debug Android APK rebuilt.
- Production web build passed. Existing non-blocking image lint warnings remain.
- Live PostgreSQL + API + AI-service browser flows: **2 passed** (desktop and mobile).
  Desktop imported all **2,007 contacts** and mobile browser imported 107. Verified
  circle reuse, no automatic relations, exact-repeat deduplication, private API
  synchronization and preservation of manual circle corrections.
- Public production browser checks: **8 passed**, including CSP and accessibility. Chatbot browser regression checks: **2 passed**.
- PostgreSQL migrations V59/V60 applied successfully to the backed-up restored
  preview. Web, API and AI readiness checks returned HTTP 200.
- Live Google/Microsoft credentials were **not configured**; provider traffic was
  mocked. Physical permission dialogs and iOS builds are **not certified**.

Evidence: `.tools/contacts-api-verify.log`, `contacts-provider-tests.log`,
`contacts-ai-tests.log`, `contacts-web-unit-final.log`, `contacts-mobile-tests-final.log`,
`contacts-mobile-analysis-final.log`, `contacts-apk.log`, `contacts-web-build-final.log`,
`contacts-browser.log`, `contacts-public-browser.log`. Browser screenshots are
`.tools/preview/contacts-desktop.png` and `contacts-mobile-web.png`.


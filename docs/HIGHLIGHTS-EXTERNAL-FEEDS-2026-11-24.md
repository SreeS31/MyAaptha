# Frequent people, external advisor feeds and audio-only notes - 24 November 2026

## Private people highlights

Contacts now shows Frequent, Starred and Hidden. Frequent suggests up to twelve people with at least two answered MyAaptha direct calls in the last 90 days. New communication calls count only when both participants joined; answered legacy calls require an answer. Declined/missed invitations, circle calls, old calls, other users' calls and blocked/inactive accounts are excluded. Historical LEFT membership without recorded join evidence is not guessed to be an answered call. Migration 80 records joined_at for future calls; only currently joined memberships are backfilled.

Stars are personal shortcuts, with no total quota and paginated retrieval. Private imported contacts can be starred from their contact card. Suggestions can be hidden/restored or disabled entirely without removing stars. This does not read device call logs, infer family roles or assign Trust/Star/emergency privileges. Existing relationships, private calls and previously chosen members authorize member starring.

## External advisor feeds

Advisors > External feeds connects an explicitly chosen advisor to a public HTTPS RSS/Atom feed or a YouTube UC channel feed. The connection imports up to 50 publisher-supplied text previews per fetch. No remote images/video bytes are copied. Previously imported entries are deduplicated by source/link and retained; current feed windows are not a complete historical export. Multiple sources/advisors are supported, with pagination and no total source quota.

Sources refresh periodically in bounded batches (five due sources per five-minute pass, at least 30 minutes between scheduled attempts). Manual refresh has a one-minute cooldown; per-user/global outbound request limits also apply. Pause stops scheduled refresh while retaining saved previews. Disconnect removes that source and its private imported previews/saves. Current category membership filters the feed. Likes and saves are local MyAaptha choices, not upstream likes. Repost requires confirmation and creates a MyAaptha post containing only the title and original link. Share/copy sends the link; reading the original opens its website.

Source URLs and preview payloads use field encryption and owner-scoped APIs. Consent is explicit when connecting. The HTTP client uses a custom resolver that validates the actual resolved connection addresses, HTTPS verification, no redirects or cookies, bounded time/body size (2 MB), and no private/reserved addresses. XML entities/DTDs/XInclude/external resources are disabled; HTML is rendered only as stripped text. Errors do not disclose upstream credentials or responses. Fetch failures preserve saved items. Disabled accounts are not scheduled.

Instagram automatic imports remain dependent on a configured Meta application, account eligibility and permitted OAuth access. The official Instagram Login API serves businesses and creators; a personal advisor profile link does not authorize importing its feed. This implementation does not scrape private accounts or ask users for social-network passwords. [Meta documentation](https://developers.facebook.com/documentation/instagram-platform/instagram-api-with-instagram-login).

## Audio-only notes

Native messaging now uses record 7.2.0 AAC microphone capture on Android/iOS instead of the previous video-dependent WebRTC recorder path. It requests microphone permission, never a camera for voice notes, stops/discards on backgrounding or call cancellation, limits duration/size and removes the temporary file after returning review bytes. Permission denial creates no file or attachment. iOS microphone copy now mentions voice notes and duplicate permission keys are removed. Existing web recording and shared upload/API formats are preserved. Real Android/iPhone hardware acceptance is still required; Windows cannot produce a verified iOS app build.

## Remaining personal/community parity

This batch does not complete the entire Instagram/WhatsApp audit. The owner has been asked for Firebase/APNs configuration for background calls and the desired E2EE/search model. Neither is assumed to be configured or complete. Large calls/live broadcasts need media-server architecture; device pairing/key recovery, communities/channels, view-once delivery, advanced media editors, private-account request semantics and other audit rows remain outstanding. Commercial features remain deferred. See INSTAGRAM-WHATSAPP-PARITY-2026-11-23.md.

## Validation and deployment

Targeted call regression: six existing call tests passed. Six new backend cases cover answered-call scope, hidden/disabled suggestions, 55 private contact stars and pagination, owner isolation, consent, feed deduplication/local actions, safe errors with retained saves, RSS/Atom parsing and blocked XML/network addresses. Native recorder lifecycle tests cover review bytes, discard and denied permission. Final browser/native/CI/deployment results are recorded after completion.

Targeted production browser validation: eight desktop/mobile cases passed, including accessibility and viewport fit. Native: 24 targeted tests passed, including recorder lifecycle and existing contact-import/permission checks; analysis clean. A real public-feed probe exposed an overly broad IPv4 exclusion; the filter now uses the precise reserved subnets, with a regression for a public publisher address.

## Configuration needed for the next parity work

Current Android application ID is `com.myaaptha.myaaptha_mobile`; iOS bundle ID is `com.myaaptha.myaapthaMobile`. Firebase app registrations must match those identifiers. No Firebase app configuration files were found in this repository. The owner needs to confirm whether Firebase is configured for the existing GCP project and whether an Apple Developer/APNs key is available. Keep private provider keys in the protected deployment configuration, not chat or Git.

Firebase's [Flutter messaging setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started) requires Apple push/background notification capabilities and an APNs authentication key for iOS. Credentials alone do not implement native incoming-call lifecycle or prove device delivery. The remaining work includes client/server integration and real-device acceptance.

For encrypted messaging, the unresolved choice is encrypted-by-default with local search, or separate encrypted chats alongside existing server-searchable chats. Server-side message AI/search cannot read end-to-end encrypted text. Device identity, recovery and multi-device behavior need to follow that choice and a reviewed protocol/library.

## Final release evidence

Application source `b1afdf42204f4b9cee98000f8694a47be1f05541`, tag `beta-20261124-highlights-feeds-r3`, is deployed to the GCP beta. [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45443732001) and [image validation/scans](https://github.com/SreeS31/MyAaptha/actions/runs/45443731971) passed. Final CI: 320 backend tests (zero failures/errors, one skip), 94 browser scenarios, 26 web unit tests and 136 native tests (two expected skips); native analysis clean. Android debug build succeeded with the audio recorder plugin.

The initial frontend run found an unhandled malformed highlights response in older contact fixtures. Highlights now fail locally without breaking contact import/search, with dedicated regression coverage and updated fixture contracts. The diary layout assertion now selects the visible accessible main region rather than a hidden Suspense fallback. A redundant unrelated refresh button was removed from External feeds before final image validation. A supplemental Windows layout run hit existing timing limits and was stopped after the full Linux CI suite passed; no failed candidate was deployed.

Migration 80 is applied. Fresh backup `/opt/myaaptha-beta/runtime/release-backups/20261124T171023446479Z.dump` was restored into an isolated database and its user count verified before migration. Exact running digests, HTTPS health UP and schema 80 were checked. Existing Google Contacts and authenticated TURN configuration/service were preserved. No additional public firewall ports or provider credentials were required.

Four live desktop/mobile scenarios passed: private contact starring, suggestion opt-out, real public RSS preview import, local likes/saves, retaining saves after pause, viewport fit and public navigation/accessibility. Separate live API checks passed for two answered call sessions, private stars/hiding/opt-out, owner isolation, RSS imports, local actions, pause and confirmed original-link repost. These call tests exercise control-plane membership, not real phone media. The synthetic link post was removed through its author's API. Standalone public probes returned ten RSS and fifteen YouTube Atom previews.

Matching Android test APK: `.tools/preview/MyAaptha-beta-highlights-feeds-20261124.apk`, SHA-256 `a4e535d1c62efdf2e94296d0c587639948dfad479f71692bb6ad33fa667576eb`. This is a debug test build, not an app-store publication or verified iOS binary. Real-device microphone/call acceptance remains pending.

Guarded cleanup removed four exact synthetic accounts and their owned data. All fifteen remaining-count checks are zero, including contacts, calls/members/signals, highlights/preferences, external sources/items, trees, advisors, reposts, finance records and active uploads. User contacts were not used as fixtures or changed. Immutable images, overlay hash, backup and test evidence are recorded in `infrastructure/production/highlights-feeds-images-20261124.json`.

After cleanup, HTTPS health remained UP, schema 80 and exact running image references matched the release, and Google Contacts/authenticated TURN remained configured.

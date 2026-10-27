# Native contact permission parity

18 October 2026. Engineering work under **M04.5**; physical Android/iOS acceptance remains pending with **M16.3**.

The address book and contact organizer now use one permission/read boundary. Previously the address book accepted limited access while the organizer required full access. Both now accept granted or limited permission and read only records returned by the operating system. The shared reader makes no HTTP request and does not save contacts.

| Permission / situation | Read behavior | Persistence / analysis |
|---|---|---|
| Granted | Read returned device contacts after permission | Address book opens review; organizer analyzes only after its explicit action |
| Limited | Same flow, restricted to OS-returned records | No expansion to unpermitted contacts |
| Denied / restricted / permanently denied / provisional | No contact-plugin read | No analysis/import; actionable denial message |
| Screen left while permission is pending | Skip contact read when permission returns | No upload or update to disposed state |
| Empty permitted set / no named analysis candidates | No analysis request | Explain that nothing was uploaded |
| Repeated organizer taps while permission is pending | One in-flight operation | At most one analysis request from those taps; no automatic save |
| Browser | Native reader refuses access | Use supported CSV/vCard import instead |

The organizer now handles permission errors inside the existing busy/error lifecycle. It checks whether the screen is still mounted before calling analysis. The address book keeps review and selected-record import; granting permission does not itself save the phonebook. The existing device-settings button remains available in the native address book. Copy describes permission-allowed records rather than promising the entire phonebook.

No API schema or web implementation change is required. Device review continues to use `/api/address-book/import-reviewed`; organizer analysis and acceptance remain separate endpoints with explicit consent. Web and native saved address books remain account-owned. This change neither enables OAuth nor calls an external AI provider.

## Verification scope

`device_contact_permission_test.dart` simulates the installed permission/contact plugin method channels, rather than bypassing the permission boundary. It covers denied statuses without reads, granted read order/cache cleanup, limited organizer analysis, limited address-book review before import, denial without upload, cancellation while waiting, duplicate taps and empty permitted contacts. Existing selected-record/batch import tests remain included in regression.

The opt-in native live scenario additionally saves one selected synthetic device contact, checks persistence in another authenticated session, rejects deletion from another account, verifies that no relationship was added and removes the saved fixture. It connects only to the local preview. No real phonebook is read.

Desktop and phone-browser address-book scenarios independently exercise the shared API and review/save flow using generated CSV records. These HTTP/widget checks establish local engineering behavior; they do not certify iOS permission dialogs, selected-contact OS filtering or Android device behavior.

## Physical acceptance still required

On selected physical Android/iOS builds, record OS/version, exact signed build identity, initial permission state, granted/limited/refused/revoked behavior, leaving the dialog, empty contact access, selected-record persistence and account isolation. Validate any platform-specific permission configuration on the actual iOS build host. No physical device or iOS archive was available for this development batch, so M04.5 is not closed.

Recorded results: 11 new permission tests; 64 full native regression checks passed with one opt-in live skip; clean native analysis; explicit actual native HTTP scenario passed; both desktop and phone-browser import cases passed. Focused permission/import run: 15 passed. Logs are `.tools/launch-board/contact-permission-{focused-final,analysis,regression,native-live,web-sync}.log`.

The updated Android debug APK built successfully (`contact-permission-android-build.log`). The handbook HTML/PDF was refreshed with this permission flow, and its desktop/390px rendering checks passed. Launch-board interaction verification passed with zero script errors (`contact-permission-board-final.log`). The app, API health and board returned HTTP 200 after these checks.

Final artifact checks: the previous build record rejected the changed APK; refreshed API/web/debug-APK identities matched successfully. `releaseApproved` remains false. Evidence: `contact-permission-old-artifact.log`, `contact-permission-artifact-record.log`, `contact-permission-artifact-final.log`. The initial scan was slow and the attempted process stop failed; the original verification workflow subsequently completed successfully without stopping application services.

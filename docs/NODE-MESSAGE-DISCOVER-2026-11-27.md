# Node messaging and page Discover

The saved-tree person panel has a Message action above Edit person. It opens the matched MyAaptha direct conversation so the user can compose and send a message. The server resolves only identifiers from the owner's linked private contact; there is no name-based guessing. Conflicting identifiers, self, blocked accounts, inactive/managed identities and unavailable contacts do not produce a target. A target must be discoverable or already in the owner's relationships. The selected private contact ID is carried into the composer and revalidated before the first send. No relationship is created automatically, and no message is sent until the user writes and sends it.

Discover appears in the shared top bar and searches text currently loaded on that page, excluding sidebar navigation. Matches are highlighted with previous/next controls; clearing or navigating resets the search. It does not search unloaded or collapsed data. Native mobile has the equivalent top-bar Discover action, excludes inactive pages, and scrolls to a chosen result. Existing page-specific server searches remain available.

The messaging API is additive and requires no database migration. The Message action and availability handling use the same API on web and native mobile.

<!-- DEPLOYMENT-STATE:START -->
Source `f4a83a145f919ef0ff1827f1c7e1937cf4bb8705`, tag `beta-20261127-node-discover-r4`, passed [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45928253956) and [image validation](https://github.com/SreeS31/MyAaptha/actions/runs/45928254055): 324 backend tests (one skipped), 108 browser scenarios, 30 web unit tests, clean native analysis and 143 native tests (two skipped). The targeted first-send test verifies delivery plus rejection of foreign-contact and wrong-recipient attempts. The matching Android beta APK is built.

Deployment is pending a scanner-health decision. Both candidate containers became healthy, but overall API health rejected signature build age over 48 hours, so the updater restored the previous application images. FreshClam reports version 28194 (built 2026-11-25 06:26:59 UTC) is the publisher's latest. No scan or freshness check was disabled. A beta-only 72-hour proposal is awaiting user approval. First-send live delivery remains unverified until deployment succeeds. Four preliminary synthetic accounts and all their fixtures were removed; all 15 scoped cleanup counts are zero. The database was not restored.
<!-- DEPLOYMENT-STATE:END -->

Release validation and deployment evidence will be recorded after publication.

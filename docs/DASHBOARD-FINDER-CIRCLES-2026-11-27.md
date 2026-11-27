# Dashboard, finder and automatic circles

Dashboard metric cards link to relationships, circles, managed profiles, unread messages and notifications, including zero counts. Network chart values and circle ownership totals also link to their destinations. Mobile dashboard cards provide corresponding navigation.

The top field is now **Find people & Circles**. It combines current-page matches with accessible people and circle results, with a link to the complete search page. Duplicate sidebar search entries and the repeated dashboard search disclosure are removed. Mobile uses the same label and combined search.

Automatic private-contact grouping requires at least three distinct saved contact records. Suggestions accumulate across import batches until that threshold is met. Imported contacts are not invited to conversations. Manual circle creation and explicit assignment remain available at any size. The legacy AI organizer also requires three distinct confirmed people before creating a suggested circle.

Migration V82 preserves pending source labels and removes only untouched legacy automatic circles with fewer than three private contacts. It preserves manual circles, circles with other members/admins, messages, posts, calls, activities or chat settings, and all private contacts. Explicit circle edits mark the circle as manually maintained.

Local validation: automatic-circle/address-book tests (9), AI organizer tests (2), mobile navigation/finder tests (6), clean Flutter analysis, and a successful web production build. All 14 targeted desktop/mobile browser checks passed sequentially. The parallel local browser run encountered Chromium session timeouts; the sequential run passed without application changes. One new search fixture was corrected to include the API-required circle owner name.

GCP deployment remains pending the existing antivirus freshness gate. No scanner security policy is changed by this release. Automatic approval review rejected the earlier proposed 48-to-72-hour relaxation because explicit approval for that setting was absent.

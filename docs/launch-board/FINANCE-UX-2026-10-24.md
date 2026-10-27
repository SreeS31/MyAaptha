# Finance experience refresh - 24 October 2026

## User experience

The monthly income, spending and net-saved overview now appears before the renewal tracker. A calm green palette, consistent icons, readable amounts, rounded cards and lighter supporting text give the page a clearer hierarchy. The net-saved help explicitly distinguishes recorded cash flow from a bank balance.

The renewal empty state is compact and offers Bill, Warranty and Service plan shortcuts that preselect the editor type. Search/filter controls appear once records exist. Due-soon and expired counts also act as quick filters, and reminder offsets are displayed as short day badges. Existing receipt, notes, edit, renewal, archive/restore, deletion and reminder behavior remain available. Adding or renewing an item resets filtering so the saved record is visible.

A header action opens transaction entry and focuses the relevant field. Manual and pasted-SMS modes remain available. Transaction activity now supports search, income/expense filters and clearing filters. Deletion requires confirmation; cancelling keeps the record. Submit feedback appears beside the form. Cash-flow charts, category totals and the existing educational suggestions/disclaimer remain accessible.

## Data and implementation

Existing Finance and renewal APIs, ownership checks, timezone rules, receipt storage and reminder schedule are unchanged. Monthly fetch responses are sequenced to prevent a delayed earlier request from overwriting a newer month. The month filter applies to transactions; renewals remain visible independently. No automatic payments, bank connections or new financial-advice rules were added.

This refresh changes the responsive web interface. Existing Flutter clients continue to use the same shared APIs and records; this work does not claim a native visual redesign or physical-device certification.

## Local verification

Production build and type checks are recorded under `.tools/launch-board/finance-polish-*`. Synthetic desktop/phone scenarios cover the empty overview, type shortcuts, quick filters, manual income/expense entry, activity search/filtering, SMS-mode availability, cancellation/deletion, receipt and renewal flows, and UTC month boundaries. Focused accessibility checks cover contrast, form labels, button names and ARIA values. Final results are appended after the reviewed build completes its checks.

An initial overview test selector was corrected to account for the heading's existing help-button label. Accessibility then identified low contrast on the month label; the label was darkened. Visual review also restored page gutters and compacted the phone balance card. These initial attempts are not counted as passing final overview scenarios.

## Final results

- Production web build passed: `finance-polish-web-build-reviewed.log` (includes type/lint checks).
- Six scenarios passed against the final build, three each on desktop and Pixel 7 mobile-web: `finance-polish-browser-final.log`. Manual save, filters, cancellation/deletion, receipts, pause/renew/archive/restore and UTC cookie/bearer reporting passed.
- The two overview scenarios reported zero violations for the four selected accessibility rules and zero recorded page errors/horizontal overflow. This is a focused check, not a full WCAG certification.
- Empty and populated desktop/phone screenshots under `.tools/preview/finance-polish-*.png` were reviewed. Finance, API health and the launch board returned HTTP 200.
- API, assembled web and unchanged Android debug APK identities recorded and verified (`allPresent=true`, `matches=true`, `releaseApproved=false`) in `.tools/launch-board/build-identities-finance-ux-20261024.json`.

Launch totals remain 61/90 complete, 29 pending. A visual/interaction refinement does not close external release gates.

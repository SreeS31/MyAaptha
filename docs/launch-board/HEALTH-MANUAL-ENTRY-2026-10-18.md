# Manual health entry — 18 October 2026

This delivers the local web/native form work tracked as M09.5. Provider analysis acceptance remains a separate gate, M09.4.

## Shared behavior

- Native supports a selectable collection date, notes, a private diary link and multiple measurements. Both clients support adding/removing rows, up to the API's existing 500-row limit.
- Blank or partial rows, non-finite/out-of-range values and reversed reference ranges are rejected. Zero and negative measurements remain valid within existing numeric bounds; the form does not infer clinical meaning.
- Saving disables controls to prevent duplicate in-flight submissions. Failures keep the draft open and preserve its values. Errors are revealed in the form. Explicit cancellation discards the draft; drafts are not written to local persistent storage.
- Success closes/resets the form and refreshes history. This is not an idempotency guarantee after an unknown network outcome; no automatic retry is introduced.

## API and storage alignment

| Field | Maximum |
|---|---:|
| Report name / laboratory | 200 characters |
| Notes | 1,000 characters |
| Metric name | 120 characters |
| Unit | 40 characters |
| Suggestion in the API input | 500 characters |
| Measurements per report | 500 |
| Absolute numeric value / reference bound | 1,000,000,000 |

The API now rejects manual inputs longer than stored limits instead of accepting and shortening them. Collection date and values are required. Existing saved records are unchanged. The native live scenario checks exact-limit values through encrypted persistence and back, including account isolation.

## Verification scope

Backend boundary/service/consent tests cover accepted limits, rejected overflows and required values. Native tests cover draft preservation, retry, multiple rows, range validation, removal, error visibility and busy controls. Browser scenarios simulate a failed handoff, retain the draft, retry against the real API and verify one saved report containing both measurements, including zero.

These checks use synthetic values and do not call a health analysis provider. Physical-device acceptance and optional provider/privacy approval remain open.

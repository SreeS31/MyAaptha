# AI answer reuse and optional stronger replies

Local test page: http://localhost:3000/help

## Behavior

- Base help model remains `gpt-4.1-mini` (`MYAAPTHA_HELP_MODEL`).
- Stronger retry model defaults to `gpt-4.1` (`MYAAPTHA_HELP_ENHANCED_MODEL`). No automatic paid escalation. Changing either environment value requires a server restart.
- A platform administrator opens **Ask MyAaptha → Administrator: AI cost controls → Allow users to try a stronger model**. This setting is saved in the database and is off by default.
- After a base AI or saved answer, the user explicitly clicks **Not satisfied? Try stronger model**. The server checks the admin setting and ownership of the original answer, then uses the original question/context rather than trusting a replacement client payload. Retrying an already enhanced answer is rejected. A matching enhanced answer can itself come from private cache.
- Existing AI account opt-in remains enforced. There is no client-selectable arbitrary model. Global/user request guards and the four-request in-flight guard remain; stronger attempts have an additional two-per-user 24-hour state counter. These are request guards, not monetary limits; failed attempts can also consume a counter. Production uses Redis state; local in-memory counters reset with the process.
- The provider receives relevant approved help articles (up to three) and bounded recent conversation instead of the entire help manual. Questions without a lexical help match, including in the most recent context, return application help without a provider request. This is conservative retrieval, not semantic or multilingual similarity search.
- OpenAI responses remain capped at 650 output tokens and use `store: false`. Input/output usage returned by the provider is recorded for successful AI responses.

## Database and privacy

Migration `V65__help_answer_memory.sql` adds help settings, exchanges and approved shared answers.

Valid help requests and replies, including cached/help-only responses, are stored with user ownership, question/context, sources, mode, model, timestamps and token usage. Payloads use the existing field-encryption service (encrypted when deployment field encryption is enabled). They respect the existing AI activity-retention preference, default 90 days; zero disables storage and private reuse. Saving an answer does not override that preference. **Clear chat** deletes that user's saved help history as well as clearing the screen. Reduced retention removes old exchanges. Scheduled cleanup deletes expired rows.

Private reuse requires the same user, normalized question, exact conversation context, model and help-knowledge version. Normalization changes only whitespace, case and Unicode normalization; it preserves punctuation, numbers and negation. Cache hits do not call the provider. The indexed key includes the content fingerprint of all approved articles, so an article update invalidates old answers after restart.

An answer is not automatically exposed to other users. An administrator uses **Review for shared answers**, edits the general question/answer, checks the sources and explicitly confirms there is no private information before publishing. This does not grant administrators a new API for browsing other users' help histories. Approved answers serve identical normalized standalone questions across accounts for 30 days, or until the help content changes. Follow-up questions with history never use that shared entry. Clearing the shared cache revokes reuse, including copies logged in a user's history. Shared approval does not call AI. The cache performs no paid embedding calls or fuzzy matching.

These changes apply to the application-help chatbot. Private health reports, messages and contact records are not added to the cross-user answer cache. Other AI features retain their existing processing paths.

## Validation

- Backend: 17 tests passed (`HelpChatTest`, `HelpAnswerMemoryTest`, `AiPreferenceServiceTest`); package succeeded.
- Verified database cache hits avoid provider calls, questions/answers are encrypted with encryption enabled, users cannot read/retry each other's exchanges, regular users cannot enable retries or publish shared answers, context/model differences miss cache, expiry works, and retention/history deletion is owner-scoped.
- Web production build passed. Four browser cases passed across desktop/mobile: existing help and new admin/retry/review UI. New UI tests mock provider results and admin responses; actual backend authorization is covered separately by database/API tests.
- Flutter analysis passed; two help-chat widget tests passed. Mobile code includes admin toggle/review, explicit stronger retry and history deletion. No new APK was produced in this change.
- Local preview restarted with migration applied and stronger retries still disabled.
- One real paid request succeeded with GPT-4.1 mini: 487 input tokens, 35 output tokens. The identical second request returned mode `CACHE`, identical answer, and zero additional AI tokens. At $0.40/$1.60 per million input/output tokens, estimated standard text cost was $0.0002508. No paid stronger-model request was made.

Logs: `.tools/ai-memory-api-final.log`, `.tools/ai-memory-web-final.log`, `.tools/ai-memory-mobile.log`, `.tools/ai-memory-mobile-test-final.log`, `.tools/ai-memory-browser.log`, `.tools/ai-memory-browser-recheck.log`, `.tools/ai-memory-live.log`.

This is not a dollar spending cap, a 5,000-user load test, or certification of stronger-model accuracy. Account balance monitoring and production capacity validation remain separate.

# Application help and messaging update — 25 September 2026

## Application help

Web: `/help`, also linked as **Ask MyAaptha** in navigation and quick tools.
Mobile: **More → Ask MyAaptha**. Both use `/api/ai/help` and
`/api/ai/help/chat` on the authenticated application API.

The application owner confirmed MyAaptha is **free for all users**. The shared
knowledge file is `backend/spring-boot-app/src/main/resources/help/articles.json`.
Its instructions were checked against the web/mobile screens and backend
relationship and broadcast logic. Maintain this file when features change. The
assistant reads these approved instructions; it does not crawl private pages or
automatically learn from user records. Sources include the relevant app page and
the exact help article. Mobile sources expand inside the app.

Without an OpenAI key, the chat returns matching help articles, clearly labelled
**MyAaptha help**. This is a documentation fallback, not a live model answer.
Configured OpenAI answers require the user's explicit checkbox/switch consent and
enabled AI account preferences. Only the question, bounded recent conversation
and approved instructions are sent. No contacts, messages, financial or health
records are retrieved. Chat text is not saved in the application database or
browser/device storage; closing the screen clears it.

The provider uses the [OpenAI Responses API](https://developers.openai.com/api/reference/python/resources/responses/methods/create)
with `store: false`, structured answers, a 650-output-token ceiling and a 20-second
request timeout. This does not guarantee zero provider retention. Source IDs are
validated against server-owned articles; links are never taken from model output.
Requests are limited to 10 per user per minute and 60 across replicas by default,
with at most four active provider calls per API process. Failure or exhausted
budgets return clearly labelled application help. The assistant cannot perform
account changes or send messages.

### Enable OpenAI locally

Run in a terminal under your Windows account:

```powershell
powershell -ExecutionPolicy Bypass -File infrastructure/configure-openai-local.ps1
powershell -ExecutionPolicy Bypass -File infrastructure/stop-local.ps1
powershell -ExecutionPolicy Bypass -File infrastructure/start-local.ps1 -SkipBuild
```

The first command asks for the key without displaying it and stores a Windows
user-encrypted value in ignored `.tools/preview/openai-key.dpapi`. Do not commit or
send keys in chat. An existing `OPENAI_API_KEY` environment variable takes
precedence. Production should inject the key through its secret manager or
Spring config-tree `openai_api_key`; this Windows helper is local-only.
`MYAAPTHA_HELP_MODEL` defaults to the existing integration's `gpt-4.1-mini`.
`MYAAPTHA_HELP_REQUESTS_PER_MINUTE` controls the shared provider-call allowance.

After restarting, enable **Use OpenAI answers** in the chat. API-key validity,
provider billing and live model answer quality require a real configured key and
have not been certified by mocked provider tests.

## Direct messaging

- Star/unstar any non-deleted message and browse **Starred** in that chat.
- Pin/unpin messages **for me** and browse **Pinned for me**. These are private
  bookmarks, not shared announcements or timed WhatsApp-style group pins.
- Pin/unpin conversations at the top of your own inbox.
- Stars, pins and receipt preferences persist on the server and sync between
  web and mobile under the same account. Other participants cannot see your flags.
- Sent means the server accepted the message. Delivered means the recipient app
  requested that conversation page. Read requires an explicit acknowledgement
  from a visible, foreground chat message. These statuses do not prove that a
  human understood the message. Earlier stored receipt timestamps are preserved.
- **Share read receipts** in Messages controls visibility in both directions for
  direct conversations. Internal unread counts still update; circle read counts
  retain their existing behavior.
- Per-message web controls now support reply, reactions, copy, edit, delete for
  everyone, star, private pin and message information for older messages as well
  as the latest. Mobile exposes these in **Message actions**.
- Saved-message views use bounded cursor pagination; deleted content is excluded.

Migration V58 adds account-scoped message flags, conversation pins and read-receipt
preferences without rewriting existing messages. Ownership is checked before
flag/receipt mutations. Per-user row locking serializes concurrent flag changes.

## WhatsApp comparison and remaining scope

The [WhatsApp starred-message guide](https://faq.whatsapp.com/1221996151866148/?cms_platform=web&locale=en_US)
and [read-receipt guide](https://faq.whatsapp.com/665923838265756/?cms_platform=web&locale=en_US)
were used to clarify the requested behaviors. MyAaptha is not a complete WhatsApp
replacement and is not claimed to have feature parity.

Already present: direct/circle conversations, replies, reactions, text search,
attachments, sender editing/deletion, typing/presence, relationship broadcasts,
blocking and audio/video call signaling. Calling still needs real-device and
network testing.

Archive/mute/unread chat management and forwarding were added in the
[26 September update](messaging-2026-09-26.md).

Still outside this release: shared/timed message pins, voice-note recording/playback receipts,
disappearing messages, view-once media, polls, encrypted backups, end-to-end
encryption, multi-party calling and WhatsApp interoperability. Those require
separate implementation and verification; existing server encryption is not
end-to-end messaging encryption.

## Validation

- API verification/package: **115 tests passed, zero failures/errors/skips**, with
  real Redis enabled. Includes ownership, private flags, unread accounting,
  receipt visibility, deletion, request validation, provider output/timeout/error
  handling, source allowlisting and `store: false` payload verification.
- Flutter analysis: no issues. Flutter tests: **18 passed**, including help opt-in,
  clear-chat behavior, message stars/pins and offscreen receipt prevention.
- Final help-article relevance change: eight targeted API tests passed and the API jar was repackaged.
- Web unit tests: **7 passed**.
- Android debug APK rebuilt with both feature sets. Existing Kotlin-plugin and
  SDK XML-version warnings remain; this is not a signed store release.
- Current preview database backed up before migration in ignored
  `.tools/preview/pre-v58.dump`; the preserved original database was untouched.

- Production web build passed; existing non-blocking image lint warnings remain.
- Desktop/mobile integration: **12 passed**, covering sourced help, history clearing,
  web-cookie/mobile-bearer synchronization, login errors, older-message stars,
  private pins, visible-message read acknowledgements and receipt preferences.
- Public production browser checks: **8 passed** (accessibility, keyboard,
  relationship views and CSP).
- Final API, web and AI-service health checks returned HTTP 200. Preview is running
  at http://localhost:3000 using the restored database.

Live OpenAI and
physical-device validation remain dependent on provider configuration and devices.
Local logs: `.tools/chat-messaging-api-verify.log`,
`.tools/messaging-mobile-analysis.log`, `.tools/messaging-mobile-tests.log`,
`.tools/chat-final-web-labels.log`, `.tools/chat-final-apk.log`, `.tools/chat-final-api.log`, `.tools/chat-final-mobile-tests.log`, `.tools/chat-final-mobile-analysis.log`, `.tools/chat-final-browser.log`, `.tools/chat-final-public-browser.log` and `.tools/chat-final-web-unit.log`.

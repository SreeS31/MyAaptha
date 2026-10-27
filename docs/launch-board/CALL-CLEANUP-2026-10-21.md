# Calling media-resource cleanup - 21 October 2026

Related launch gate: M07.5. The existing web calling implementation could retain a newly opened microphone/camera stream when signaling failed because its catch handler referenced an earlier React render's stream state. Answer failure and route unmount also lacked complete cleanup, and end-call signaling was awaited before releasing devices.

## Implemented fix

CallResources owns local/remote streams and the peer independently of render state. Beginning or releasing a session invalidates the prior generation. Late media/peer events are stopped or closed rather than attached to a cancelled or newer call. Cleanup closes event handlers and the peer, then stops device tracks even if peer shutdown fails.

Start/answer handlers check ownership after asynchronous device/SDP/ICE/signaling steps. A server call returned after cancellation is ended through a best-effort compensating request. Ending a call releases devices and closes its UI before waiting for the server response. Unmount always releases local resources; accepted/outgoing calls also receive a best-effort end request. Merely viewing an unanswered incoming call does not automatically reject it when the page is left. A terminal peer failure releases media; a temporary disconnected state reports interruption without immediately ending recovery.

## Verification scope

Six focused resource-owner unit scenarios passed: local/remote release and idempotence, permission results after cancellation, stale work versus a newer call, late peer/track cleanup, shutdown failure and remote-stream replacement. TypeScript checking passed before the production build.

The browser scenario uses native synthetic MediaStreams from WebAudio/canvas with an instrumented fake peer and mocked signaling responses. It does not access a physical microphone/camera, call another person or contact STUN/TURN. It checks answer failure, cancellation while permission is pending, delayed end-call responses and resource release during client-side navigation. Browser/build results are appended after execution.

These checks do not establish actual audio/video transport, physical-device permissions/quality, NAT/TURN reachability, network-change recovery, native-client calling parity or production acceptance. The existing browser ICE configuration is unchanged. Calling launch scope, controlled devices and any required relay-service configuration remain owner/platform inputs. See the [owner input checklist](LAUNCH-INPUTS-2026-10-21.md).

## Final results - 22 October 2026

The production web build passed. Six resource-owner unit tests and the complete synthetic call scenario on desktop and phone browsers passed. The existing profile/timeline/storage/cross-session regression passed on both layouts. Tests confirmed setup-failure release, discarded permission results after cancellation without an accept request, immediate device release before a delayed end response, and client-side navigation cleanup with an end request. This remains synthetic media/peer verification; physical transport and network acceptance stay open.

The initial browser run's alert selector also matched Next.js's route announcer. A later phone navigation selector matched the hidden brand link and then read menu state before hydration completed. The test now uses the visible sidebar link after explicitly waiting for mobile menu state. A subsequent cold login exceeded its five-second assertion while still signing in after host resume; the assertion now allows 15 seconds, consistent with the application's 12-second request timeout. Final phone verification passed. No product behavior was bypassed or authentication/rate limits disabled.

Evidence under .tools/launch-board: call-resources-unit-20261021.log, call-types-20261021.log, call-web-build-20261021.log, call-browser-verified-20261021.log (desktop calling pass), call-mobile-final-20261022.log (phone calling pass), call-browser-20261021.log (both profile regressions passed within the earlier mixed-result run), and call-artifacts-verify-20261021.log. The exact previous UI-only identity record was preserved before replacing the current record with verified call-build identities. API and debug APK remained unchanged; release approval remains false.

[Sanitized final verification](call-cleanup-verification-2026-10-22.json).

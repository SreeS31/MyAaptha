# Messaging workspace update

The Messages route now opens direct and circle conversations inside a responsive inbox/thread workspace. Desktop retains the inbox beside the thread; phone screens use Back to return to chats. Message Info opens a side panel.

Bubbles show sender names above content, attachment previews and quoted replies, followed by short local time and direct-message delivery/read ticks. Context actions remain neutral with separate hover targets. The composer stays below the scrolling history. Existing forwarding (maximum ten destinations), server-enforced deletion rules, private stars/pins, reactions and reporting are reused.

The mobile source now labels outgoing senders and uses delivery icons with accessibility labels. This does not install a new mobile binary.

## Scope and remaining work
This is not a certification of complete WhatsApp feature parity. Circle Info currently shows aggregate read counts, not named reader receipts. Starred/pinned filtering in the new thread is explicitly limited to loaded history. Calling controls remain in the existing dashboard, not the new Messages pane. New chat targets use existing eligible people and writable circles. Full encryption, calling parity and all WhatsApp features have not been audited or established by this change. No new capacity or 5,000-concurrent-user result is claimed.

## Validation
Production web build and TypeScript completed successfully. Both Playwright scenarios passed (desktop and Pixel 7): ten-target forwarding limit, combined inbox, opening circle chats in place, sender above body, timestamp below body, visible composer, Info panel and starring. Flutter analysis reported no issues and all five messaging widget tests passed. Desktop and mobile screenshots were reviewed. Browser and Flutter verification logs are in .tools/chat-workspace-*.log.

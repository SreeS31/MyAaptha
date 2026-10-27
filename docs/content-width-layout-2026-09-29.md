# Content-sized workspace and compact chat

Shared web layouts now size headings and collapsed controls to their contents. Conversation and circle cards have bounded widths, with additional cards placed alongside them. Profile, privacy, settings, health, finance, report, notification, and administrative resource panels use responsive columns or bounded forms. Wide tables and relationship canvases retain room for their data. The rules apply independently of the signed-in user's role.

Chat input starts at 36px with one text row; users can resize it for longer messages. Action buttons wrap at their natural label widths instead of filling two broad columns. Reactions, padding, and disclosure spacing are reduced. Touch actions retain 44px targets. The private stars/pins explanation is inside Message information.

Validation evidence:

- Production build and type checking: `.tools/content-width-build.log` (existing image optimization warnings remain).
- Desktop/mobile route and messaging checks: `.tools/content-width-final-browser.log`.
- Route audits and screenshots: `.tools/ui-review/desktop` and `.tools/ui-review/mobile-web`.
- Real chat screenshots: `.tools/preview/messages-desktop.png`, `messages-mobile-web.png`, and `forward-message-*.png`.

The route audit covers 26 views per browser profile, including regular-user and admin views, typography, contrast, horizontal overflow, circle creation, bounded widths, optional forms, and side-by-side profile panels. Conversation directory layout fixtures are mocked only within the route audit. Separate messaging tests use synthetic accounts and real local APIs for stars, pins, receipts, chat management, and forwarding; they also check the input height and action widths.

Preview: http://localhost:3000/messages

This is a web and mobile-browser UI update; it does not certify native app layouts or production load capacity.

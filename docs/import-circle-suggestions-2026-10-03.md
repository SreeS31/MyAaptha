# Contact import circle suggestions

The web contact import preview now summarizes suggested circles before saving:

- Existing circles are matched case-insensitively and reused, even for one contact.
- A new circle is suggested only when at least six usable contacts with distinct primary phone numbers share an explicit label, organization, or recognized name tag.
- Missing/invalid phone entries are skipped and do not contribute to the threshold. Duplicate primary phone numbers do not inflate the count.
- Suggested circle cards show the contact count and whether a circle exists or will be created. Each suggestion can be unchecked independently.
- The threshold is recalculated from selected contacts at submission, before batching, so deselecting contacts cannot accidentally create an undersized new circle.
- Contacts without a qualifying circle are still imported into the private address book. No fallback circle is automatically created.
- Circle names remain editable per contact, with existing and suggested names available in the picker. Existing manually reviewed assignments remain protected by the existing API behavior.

File, device-picker and connected-provider previews use the same preparation function. The current circle list is refreshed before preparation. This is local deterministic matching and does not consume OpenAI credits. No sensitive traits are inferred from names; recognized name tags are text matches.

The threshold governs this web preview and submission path. The general API for explicitly reviewed assignments remains unchanged, as do native Flutter import rules.

Verification: six parser/review/batch unit cases passed. Both desktop and mobile-web browser integration cases passed, including actual saved circle counts and unchecked suggestions. Browser integration results are recorded in `.tools/import-suggestions-browser.log`; screenshots are `.tools/preview/import-circle-suggestions-desktop.png` and `import-circle-suggestions-mobile-web.png`.

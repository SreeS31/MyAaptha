# CircleNet personal assistant roadmap

## Product direction

CircleNet is evolving from a private social network into a consent-driven digital presence: one place for a person's relationships, communication, memories, records, money, health, plans, and trusted continuity.

The publicly available MyAaptha description lists unlimited personal, education, health and document storage; professional interaction; health-record storage; doctor appointments; medicine ordering; and diagnostic-test booking. This roadmap incorporates those capabilities without claiming that healthcare-provider integrations already exist.

## Navigation model

- **Connect:** relationships, messages, circles, discovery and notifications.
- **Personal assistant:** diary and memories, life timeline, money and insights, future reminders and health.
- **Identity & trust:** profile, document vault, Star Members, Role Models and emergency access.
- **Safety & control:** privacy, sessions, reports, consent history and moderation.

## Delivery status

### Available now

- Financial transactions synchronized through the API to web and mobile.
- Manual income/expense entry, monthly totals, category chart, transaction history and deletion.
- Categorization for shopping, groceries, health, investment, housing, transport, food, utilities, education, entertainment and other spending.
- Android financial-SMS import with prominent consent, device-side financial-message filtering, deduplication and revocable permission.
- Pasted-SMS/manual alternatives for web and iOS.
- Educational saving and investment considerations with a clear non-advisory disclaimer.

### Next releases

1. Budgets, recurring bills, CSV/OFX statement import and user-editable categorization rules.
2. Encrypted document vault grouped into personal, education, health, insurance, tax, warranty and property records.
3. Family health profiles, prescriptions, laboratory reports, medication schedules and emergency medical ID.
4. Reminders for bills, EMIs, birthdays, appointments, warranties and vehicle service.
5. Verified provider directory and consent-based appointment requests.
6. Medicine and diagnostic ordering only after licensed provider, payment, refund and regulatory integrations are defined.
7. Voice-first multilingual assistant, daily brief and explicit approval for every external action.

## Privacy and release requirements

- Financial data is private to its owner and must never be used for advertising or social recommendations.
- Only transactional SMS needed for money management may be processed; personal conversations must be excluded.
- Android distribution requires a Google Play restricted-permission declaration for the SMS-based money-management use case.
- iOS and web must not claim inbox-reading capability.
- Personalized investment recommendations require jurisdiction-specific compliance review. Until then, the product provides educational observations, not investment selection or execution.
- Healthcare marketplace features require verified providers, consent/audit trails, data-retention rules and applicable Indian healthcare/privacy compliance review before release.

# Trust center test strategy

The Star Member and Role Model features use layered testing:

- White-box unit/integration: `TrustControllerTest` executes the service, repositories, Flyway schema, authorization filters, media storage, and audit writes through Spring MockMvc.
- Black-box/API: the same test treats HTTP endpoints as a client and proves one approval is denied, two approvals grant access, unrelated users remain forbidden, and private contact fields are absent.
- UI and accessibility: the production Next.js build type-checks the responsive Trust center; the existing Playwright/axe public suite remains the browser baseline.
- Mobile synchronization: Flutter analysis validates the typed client methods for every Trust endpoint.
- Load: `k6 run -e ACCESS_TOKEN=... testing/k6/trust-center.js` ramps read traffic to 100 concurrent users and applies a 20 request/second spike. The acceptance thresholds are under 1% errors, p95 under 500 ms, and p99 under one second.

Emergency verification requires two independent Star Members. The request expires after 24 hours; approved access lasts one hour. Every approval, rejection, list view, and document open is stored in `emergency_access_events`. Production should additionally alert the owner through at least two configured notification channels and retain these events according to the organization’s legal policy.

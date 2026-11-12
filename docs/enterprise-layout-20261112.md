# Workspace layout update — 12 November 2026

The diary heading previously shared a tall row with the editor, leaving a large blank area before the entries. The shared web shell now uses narrower navigation, consistent page gutters, compact headings and flexible content grids. Diary and online-feed editors open on demand and retain drafts when collapsed. Wide screens show feed cards in columns; phones retain a single column and touch-sized controls.

The shared Flutter shell follows the same layout approach: compact desktop navigation, inline section tabs, fewer repeated headings and an expandable feed editor. Mobile audience selectors and attachment actions wrap without overflowing. Private diary defaults are preserved.

API contracts and authorization behavior are unchanged. Layout checks cover 16 routes at phone and desktop widths when API requests fail. These checks do not constitute a full functional or security certification of every API. Accessibility checks cover the public landing page and diary editor with WCAG 2.1 A/AA rules.

Validation: production web build; 23 web unit tests; Flutter analysis; 104 Flutter tests passed with two existing skips; 105 infrastructure tests. Browser regression results are recorded in the release workflow. Native mobile release signing is not configured in this checkout, so this update does not publish a signed mobile application.

Deployment uses the existing beta infrastructure and a scanned immutable frontend image. `infrastructure/update_beta_frontend.py` validates the target VM and image repository, backs up the runtime configuration, replaces only the frontend image, checks HTTPS and API health, and restores the previous frontend on failure. It does not migrate or reset accounts, the database or uploaded media. GitHub Actions must pass before the image is used.

The connected GCP service rejects SSH and metadata edits. The final rollout therefore needs the operator to execute a commit-pinned command in Cloud Shell. Until that command and live checks succeed, the new interface must be reported as awaiting deployment.

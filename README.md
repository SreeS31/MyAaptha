# MyAaptha

## User-uploaded media storage

Profile photos, gallery files, and conversation attachments are never written into the application JAR/WAR and are not stored as database blobs. The backend uses a shared media platform; PostgreSQL stores object metadata and application references.

- `MYAAPTHA_UPLOAD_DIR` sets the external/persistent upload directory. The local default is `./var/myaaptha/uploads` relative to the backend process.
- `MYAAPTHA_MEDIA_BASE_URL` sets the externally reachable backend origin used in stored media URLs. The local default is `http://localhost:8080`.
- In Docker/Kubernetes local-storage deployments, mount `MYAAPTHA_UPLOAD_DIR` as a persistent volume.
- Set `MYAAPTHA_STORAGE_PROVIDER=s3`, `MYAAPTHA_S3_BUCKET`, and `MYAAPTHA_S3_REGION` to use private AWS S3 or an S3-compatible cloud. `MYAAPTHA_S3_ENDPOINT` supports services such as MinIO.
- AWS credentials use the standard SDK credential chain (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, workload identity, instance role, or container role).
- Objects are encrypted with S3 AES-256, signed download URLs are supported, and uploads receive checksum, file-signature, scanner, thumbnail, quota, retention, and deletion handling.
- `MYAAPTHA_MEDIA_USER_QUOTA_BYTES` changes the default 1 GiB per-user quota.

MyAaptha is an enterprise-grade platform architecture for AI-native collaboration, identity, and knowledge workflows. This repository establishes the initial foundation for the platform and is structured to support future frontend, backend, infrastructure, and AI modules.

## Delivery status

As of 16 August 2026, all 20 engineering milestones are implemented and verified. The latest milestones add the shared social feed/stories, cross-channel account blocking, and rich private-message interactions. Production activation still requires deployment-owner cloud/provider credentials and operational validation. See [Milestone Status](docs/milestone-status.md) for evidence and the external launch checklist.

## Milestone 1: Foundation Repository

This milestone delivers the core repository scaffolding for a production-ready engineering workflow:

- Repository metadata and licensing
- Standardized editor and Git configuration
- Container-based local development environment
- CI workflow that validates repository structure and runs backend, frontend, AI, and mobile checks
- Initial module directories for future implementation

## Milestone 2: Relationship Domain Foundation

This milestone delivers the secured backend domain APIs for the collaboration graph:

- User and person management
- Circles and relationship management
- Permission management
- Authenticated CRUD endpoints with missing-resource handling
- Integration coverage for each relationship-domain API lifecycle

## Milestone 3: Project Delivery Foundation

This milestone provides the delivery-planning backend capabilities:

- Projects, milestones, and tasks
- Milestone status updates, blocking reasons, and bulk status changes
- Task filtering by milestone and milestone filtering by project
- Authenticated dashboard summary data
- Flyway migrations, data-quality constraints, and development seed data

## Milestone 4: Web Design System Foundation

This milestone establishes the shared web presentation baseline:

- Design tokens for color, typography, spacing, radii, and elevation
- Reusable layout, component, and utility styles
- Responsive design-system demonstration page
- A documented foundation for the Next.js application

## Repository Structure

- [docs](docs)
- [frontend](frontend)
- [backend](backend)
- [database](database)
- [deployment](deployment)
- [infrastructure](infrastructure)
- [mobile](mobile)
- [ai](ai)
- [testing](testing)
- [tools](tools)

## Technology Baseline

- Java 21 LTS
- Spring Boot 3.x
- Next.js 15
- React 19
- TypeScript
- PostgreSQL 17
- Redis
- Docker
- Node.js 22 LTS

## Quick Start

1. Review the repository structure.
2. Start local infrastructure services:
   - `docker compose up -d`
3. Use the development helpers:
   - `make help`

## Development Commands

- `make help` - Show common commands
- `make docker-up` - Start local infrastructure services
- `make docker-down` - Stop local infrastructure services
- `make ci` - Run repository validation steps
- `make ai-install` - Install AI service dependencies
- `make ai-run` - Run AI service locally
- `make ai-test` - Run AI service test suite
- `make mobile-get` - Install Flutter mobile dependencies
- `make mobile-test` - Run Flutter mobile tests

## Milestone 5: AI Module Foundation

Milestone 5 starts with an initial AI service module under `ai/agent-service`.

Current capabilities:

- FastAPI service scaffold with health endpoints
- Versioned API namespace (`/api/v1`)
- Strongly typed request/response models
- Config-driven behavior via environment variables
- Test baseline for service health checks

## Milestone 6: Mobile Foundation

Milestone 6 starts with an initial Flutter module under `mobile/flutter-app`.

Current capabilities:

- Android, iOS, and browser-preview Flutter targets
- Material 3 design system with adaptive phone/tablet navigation
- Sign In, Sign Up, JWT refresh, persisted sessions, logout, and revocation
- Relationship discovery, privacy/verification tags, and relationship creation
- Circle creation and private/group conversation experiences
- Profile, address, communication, education, and employment fields
- Authenticated image, audio, video, PDF, and document attachment display
- Native camera, microphone, and media permission declarations
- Widget tests and clean Flutter static analysis

## Milestone 7: Web Authenticated Dashboard

Milestone 7 secures the Next.js dashboard with backend JWT session flows.

Current capabilities:

- Web sign-in page integrated with `POST /api/auth/login`
- Browser session persistence for access and refresh tokens
- Automatic token refresh fallback via `POST /api/auth/refresh`
- Authenticated dashboard API calls using bearer access tokens
- Web logout flow integrated with `POST /api/auth/logout`

## Milestone 8: Web Session Bootstrap Experience

Milestone 8 improves public-to-authenticated flow on the Next.js web app.

Current capabilities:

- Landing page always remains available without login
- Public auth service health check integration via `GET /api/auth/health`
- Session-aware landing behavior that enriches workspace data for signed-in users
- Sign-out action available directly from the landing navigation
- Consistent authenticated handoff to dashboard workflows

## Milestone 9: Session Identity Introspection

Milestone 9 adds authenticated user identity introspection for web clients.

Current capabilities:

- Backend `GET /api/auth/me` endpoint for access-token session profile retrieval
- Bearer-protected auth-me path via JWT security filter and security chain rules
- Frontend session profile client integration for landing and dashboard experiences
- Signed-in identity context displayed in web navigation surfaces

## Milestone 10: Web Session Control Center

Milestone 10 adds first-class web session lifecycle controls and observability.

Current capabilities:

- Dedicated session control page at `/session`
- Live session identity and token lifetime visibility for signed-in users
- Manual access token refresh workflow using `POST /api/auth/refresh`
- Explicit session revocation workflow using `POST /api/auth/revoke`
- Unified navigation entry points to session controls from landing and dashboard pages

## AI Contact Organizer

After sign-in on Android or iOS, MyAaptha can optionally request contact access and suggest relationships and circles from saved names, labels, organizations, and education keywords. Suggestions include confidence and reasons and must be reviewed and confirmed by the user. Skipping is always supported, permission can be revoked, and the stateless AI analysis does not retain raw phonebook contacts.

## Quality Standards

This repository is intended to support the following standards from the start:

- Consistent formatting
- Repeatable local development
- Container-based dependency management
- CI validation
- Clear documentation and scaffolding

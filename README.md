# MyAaptha

## Launch readiness

[View launch board locally](http://127.0.0.1:4317) · [Offline board](docs/launch-board/index.html) · [Module and subtask status](docs/launch-board/STATUS-2026-10-20.md). Snapshot: 20 October 2026; 18 modules, 89 tracked subtasks, 60 recorded complete and 29 pending. Scope adds completed local engineering tasks M08.5, M09.5 and M15.9. [Latest development results](docs/launch-board/DEVELOPMENT-2026-10-20.md). Local completion is separate from production launch approval. Start the board with `powershell -NoProfile -ExecutionPolicy Bypass -File infrastructure/start-launch-board.ps1`.

## Corporate documentation

Project architecture, roles, workflows, use cases, API examples and operations: [Corporate handbook](docs/corporate/PROJECT-HANDBOOK.md). An [offline HTML edition](docs/corporate/PROJECT-HANDBOOK.html), [printable PDF](docs/corporate/PROJECT-HANDBOOK.pdf), [API catalog](docs/corporate/api-catalog.md), [data dictionary](docs/corporate/data-dictionary.md) and [editable ER diagrams](docs/corporate/er-diagrams.md) accompany the handbook. Snapshot: 20 October 2026; 71-page PDF, 229 extracted HTTP mappings and 67 migration-declared tables; implementation and release limitations are documented explicitly.

## Local preview

Latest shared design, contextual help and native timeline alignment: [8 October review](docs/app-design-2026-10-08.md).

Web, native mobile and API alignment: [synchronization review and checks](docs/synchronization-2026-10-06.md).

Private contact imports and automatic circle lists: [setup and validation](docs/contact-import.md).

Messaging features, validation and remaining gaps: [26 September update](docs/messaging-2026-09-26.md).
Open **http://localhost:3000/contacts**, or **More ? My contacts** on mobile.

With Java 21, Maven, Node.js, Python dependencies and Docker installed, run
`powershell -ExecutionPolicy Bypass -File infrastructure/start-local.ps1`.
Use `-SkipBuild` when the API JAR and web production build are already current.
The preview opens at **http://localhost:3000** and uses a separate local database;
existing development database volumes are preserved. Choose **Create an account**
on the sign-in page. Logs are in `.tools/preview`.
Stop it with `powershell -ExecutionPolicy Bypass -File infrastructure/stop-local.ps1`;
the preview database is retained.

Run `npm run test:integration` from `frontend/nextjs-app` against the running
preview to check browser/mobile-API synchronization. This creates synthetic accounts.

Current test evidence and deployment limitations: [23–24 September validation](docs/validation-2026-09-23.md).

The canonical release application is the full PostgreSQL-based application:

- `backend/spring-boot-app`: Java 21 / Spring Boot API
- `frontend/nextjs-app`: Next.js web application
- `ai/agent-service`: Python AI service
- `mobile/flutter-app`: Flutter mobile application
- `infrastructure`: production templates, release validation and deployment tooling

The `.integration` linked worktree is preserved for reference and ignored by this repository. Its source (including pending application edits) was copied into the canonical directories. Builds and releases no longer depend on that worktree.

The smaller MySQL implementation in `backend/src`, `frontend/src`, `mobile/lib`, `database` and `docker` is retained for reference; it is not the production release target. Do not use its Docker files to deploy this release. Conflicting original root files were preserved under `docs/pre-deployment-root`.

## Before deployment

Read [Deployment handoff](docs/MYAAPTHA-DEPLOYMENT-HANDOFF.md) for required account details, credentials and outstanding launch gates. Dummy configuration is provided for planning; production validation deliberately rejects it.

Read [Cloud deployment](docs/cloud-deployment.md) for the rollout and rollback procedure. Never run development Compose on a public server.

## Local verification

```powershell
cd backend/spring-boot-app
mvn verify
```

```powershell
cd frontend/nextjs-app
npm ci
npm run build
npm run test:e2e
```

```powershell
cd ai/agent-service
python -m pip install -r requirements.txt
python -m pytest tests -q
```

From the repository root:

```powershell
python -m pip install -r infrastructure/requirements.txt
python -m unittest discover -s infrastructure -p "test_*.py"
```

CI validates application tests, browser accessibility, mobile analysis/tests and dependency scanning. Tagged releases wait for CI, scan container candidates, then publish images and SBOM/digest artifacts. Cloud rollout is a separate explicit operation using `infrastructure/deploy.ps1`.

Current production approval status and measured scaling/security results: [readiness report](docs/scaling-readiness.md) and [Word document](docs/scaling-readiness.docx). Public production approval remains pending the listed security and cloud-validation gates.

Latest local features: [application help chatbot, OpenAI setup and messaging controls](docs/chatbot-and-messaging-2026-09-25.md). Open `/help` on the web or **More → Ask MyAaptha** on mobile. Configure the server's OpenAI key to enable model answers; documented help works without it.

Current launch blockers and accountable-team requirements: [pending acceptance audit](docs/launch-board/PENDING-ACCEPTANCE-2026-10-20.md). Hosted board source updates refresh automatically after loading the current page.

[Web UI and form review ? 21 October 2026](docs/launch-board/WEB-UX-REVIEW-2026-10-21.md) records shared styling, keyboard/upload improvements, phone-picker hydration and health-form layout fixes, with browser verification scope.

[Owner launch-input checklist](docs/launch-board/LAUNCH-INPUTS-2026-10-21.md) lists access and decisions needed while engineering handles development, testing and integration. [Current continuation report](docs/launch-board/DEVELOPMENT-2026-10-21.md).

[22 October continuation](docs/launch-board/DEVELOPMENT-2026-10-22.md) and [current launch-input checklist](docs/launch-board/LAUNCH-INPUTS-2026-10-22.md).

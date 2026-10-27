# MyAaptha — Intelligent Relationship Network Management Platform

Enterprise-grade platform for managing relationship trees (circles) with unlimited depth, rich node profiles, ACL permissions, and cross-platform access.

## Architecture

Monorepo layout:

| Path | Description |
|------|-------------|
| `docs/` | Architecture, HLD, LLD, API, UI/UX, manuals |
| `database/` | MySQL schema, migrations, seed data |
| `backend/` | Spring Boot 3 REST + GraphQL + WebSocket API |
| `frontend/` | Next.js 15 + React 19 web & PWA |
| `mobile/` | Flutter Android & iOS app |
| `docker/` | Docker & Kubernetes manifests |
| `postman/` | Postman API collection |

## Tech Stack

- **Frontend:** React 19, Next.js, TypeScript, Tailwind CSS, Framer Motion, React Flow, Redux Toolkit, React Query
- **Backend:** Java 21, Spring Boot 3, Spring Security, JWT, JPA, GraphQL, WebSocket
- **Database:** MySQL 8 (PostgreSQL/MariaDB optional)
- **Storage:** MinIO / local filesystem
- **Mobile:** Flutter
- **Deploy:** Docker, Docker Compose, Kubernetes-ready, GitHub Actions

## Quick Start

### Prerequisites

- Java 21, Maven 3.9+
- Node.js 20+, npm
- Docker & Docker Compose
- MySQL 8 (or use Docker Compose stack)

### Run with Docker Compose

```bash
docker compose -f docker/docker-compose.yml up -d
```

Services: MySQL (3306), MinIO (9000), Backend (8080), Frontend (3000).

### Backend (local)

```bash
cd backend
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

Swagger UI: http://localhost:8080/swagger-ui.html

### Frontend (local)

```bash
cd frontend
npm install
npm run dev
```

Web app: http://localhost:3000

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

## Documentation

- [System Architecture](docs/architecture/system-architecture.md)
- [High-Level Design](docs/architecture/hld.md)
- [Low-Level Design](docs/architecture/lld.md)
- [ER Diagram](docs/architecture/er-diagram.md)
- [Deployment Guide](docs/deployment-guide.md)
- [User Manual](docs/user-manual.md)
- [Admin Manual](docs/admin-manual.md)

## License

MIT — Open source components only.

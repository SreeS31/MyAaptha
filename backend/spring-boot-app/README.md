# MyAaptha Spring Boot Backend

This module contains the initial Spring Boot backend foundation for the MyAaptha platform.

## Included areas

- Authentication endpoints
- User management endpoints
- Person endpoints
- Circle endpoints
- Relationship endpoints
- Permission endpoints

## Authentication API

- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/auth/revoke`
- `GET /api/auth/me`
- `GET /api/auth/health`

`/api/auth/me` and `/api/dashboard/**` endpoints require `Authorization: Bearer <accessToken>`.

User registration requires a unique mobile number. Email is optional and, when supplied, must also be unique. Sign in accepts either an email address or mobile number through the `identifier` request field.

## Run locally

Start the persistent PostgreSQL database from the repository root:

```bash
docker compose up -d postgres
```

Then start the backend:

```bash
mvn spring-boot:run
```

PostgreSQL is the default datasource. All API repositories, authentication tokens,
and dashboard database queries use this one datasource. Data is retained in the
Docker volume named `postgres-data` when containers or the backend restart.

To check database readiness:

```bash
docker compose ps postgres
```

### Google and Outlook contact import

Direct address-book import uses server-side OAuth Authorization Code with PKCE and read-only scopes. Register these callback URLs with the providers:

- `http://localhost:8080/api/contact-organizer/oauth/callback/google`
- `http://localhost:8080/api/contact-organizer/oauth/callback/microsoft`

Then set:

- `GOOGLE_CONTACTS_CLIENT_ID` and `GOOGLE_CONTACTS_CLIENT_SECRET`
- `MICROSOFT_CONTACTS_CLIENT_ID` and `MICROSOFT_CONTACTS_CLIENT_SECRET`
- `MYAAPTHA_PUBLIC_API_BASE_URL` for the externally reachable backend origin
- `MYAAPTHA_WEB_ORIGIN` for the web application origin

Enable the Google People API with the `contacts.readonly` scope. For Microsoft Entra, add delegated Microsoft Graph `Contacts.Read` permission. Provider tokens are used only during the one-time import and are not persisted.

## Run in production profile (no dev seeds)

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=prod
```

The PostgreSQL profile reads these environment variables (with defaults):

- POSTGRES_HOST=localhost
- POSTGRES_PORT=5432
- POSTGRES_DB=myaaptha
- POSTGRES_USER=myaaptha
- POSTGRES_PASSWORD=myaaptha123

Automated tests use an isolated H2 in-memory datasource under `src/test/resources`;
H2 is never used by the running application.

## Database migrations (Flyway)

The backend now uses Flyway versioned migrations as the canonical database source.

- Shared migrations: src/main/resources/db/migration/common
- Dev seed migrations: src/main/resources/db/migration/dev
- Current migration set:
	- common/V1__create_core_tables.sql
	- dev/V2__seed_initial_data.sql
	- common/V3__add_indexes_and_foreign_keys.sql
	- common/V4__add_data_quality_constraints.sql
	- common/V5__add_auth_tokens_table.sql

Flyway runs automatically on startup for all profiles.

- default and postgres profiles include common + dev migrations.
- prod profile includes only common migrations (no dev seed data).

Legacy script files remain in the repository for reference:

- src/main/resources/db/schema.sql
- src/main/resources/db/data.sql

## Migration policy

See migration naming, rollback strategy, and review checklist in:

- ../../docs/migration-policy.md

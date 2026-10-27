# MyAaptha Admin Manual

## Super Admin Responsibilities

- Platform configuration and feature flags
- User account suspension and recovery
- System-wide audit log review
- OAuth provider credential management
- Rate limit and security policy tuning

## Admin Dashboard

Access: `/admin` (Super Admin / Admin roles only)

### Sections

1. **Users** — search, suspend, reset 2FA, view login history
2. **Circles** — moderate public circles, resolve abuse reports
3. **System Health** — DB connections, API latency, error rates
4. **Audit Logs** — filter by user, entity, action, date range
5. **Reports** — platform growth, active users, storage usage

## Role Hierarchy

| Role | Scope |
|------|-------|
| Super Admin | Entire platform |
| Admin | Organization / tenant |
| Owner | Single circle (full control) |
| Editor | Granted nodes/branches |
| Viewer | Read-only |
| Guest | Limited invited access |

## Security Administration

### JWT Configuration
- Rotate `JWT_SECRET` periodically; invalidate refresh tokens on rotation
- Access token TTL: 15 min (default)
- Refresh token TTL: 7 days

### Device Management
- View trusted devices per user
- Revoke device sessions remotely

### Audit & Compliance
- All mutations logged with before/after values
- Export audit logs for GDPR requests
- Rollback individual changes from admin panel

## Database Maintenance

```sql
-- Rebuild closure table for a circle (maintenance)
-- Run during low-traffic window via admin CLI
```

## Backup Procedures

1. Nightly MySQL dump to object storage
2. MinIO bucket replication
3. Test restore monthly

## Incident Response

1. Identify affected users/circles from audit logs
2. Suspend compromised accounts
3. Rotate secrets if JWT leak suspected
4. Notify users per policy

## Plugin Management (Future)

Upload JAR plugins to extend relationship types or import adapters.
Plugins run in sandboxed classloader with declared permissions.

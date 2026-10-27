# Owner launch configuration

See [the reviewed owner setup plan](../../docs/launch-board/OWNER-SETUP-2026-10-26.md). These files prepare deployment; they do not provision an account or authorize promotion.

Application-owned values have been generated under the ignored `secrets/` directory. Do not replace these after encrypted production records exist without a reviewed rotation and recovery plan. Preserve the field-encryption key IDs and keep an access-controlled backup outside the application host before production use. No secret value belongs in a commit, launch-board export or chat reply.

## Integration files

The optional `compose.integrations.yml` adds a read-only config-tree mount. Supply real values as the **contents** of the following protected files; do not create placeholder files:

| Filename under `secrets/integrations/` | Purpose |
|---|---|
| `myaaptha.calls.turn-secret` | Already generated; use this same value in the protected Coturn configuration |
| `myaaptha.help-ai.api-key` | Approved application-help provider credential |
| `myaaptha.health-ai.api-key` | Approved health-processing provider credential |
| `myaaptha.contact-oauth.google-client-id` | Google application ID |
| `myaaptha.contact-oauth.google-client-secret` | Google credential |
| `myaaptha.contact-oauth.microsoft-client-id` | Microsoft application ID |
| `myaaptha.contact-oauth.microsoft-client-secret` | Microsoft credential |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` | Existing verification adapter, only if Twilio is selected |
| `TURNSTILE_SECRET_KEY` | Existing phone-challenge provider configuration |
| `myaaptha.notifications.webhook.channel` | Actual configured notification gateway channel |
| `myaaptha.notifications.webhook.url` | Real HTTPS gateway endpoint |
| `myaaptha.notifications.webhook.token` | Scoped gateway credential |

Health enablement remains explicitly false until acceptance. Notification gateway configuration is not an SES/FCM account-creation or multi-provider delivery implementation. Match the selected SMS provider's API before enabling its route. Do not expose provider credentials in web/mobile build arguments.

## Single-host database/cache prerequisites

`compose.single-host.yml` adds private PostgreSQL and Redis services without host port mappings. PostgreSQL remains `verify-full`. Redis uses a named PEM trust bundle, as supported by [Spring Boot Redis SSL](https://docs.spring.io/spring-boot/3.5/reference/data/nosql.html) and [PEM bundles](https://docs.spring.io/spring-boot/3.5/reference/features/ssl.html).

Provision these files in ignored `certs/`:

- `postgres-ca.crt`: trusted CA for PostgreSQL and the private Redis service.
- `postgres-server.crt` / `postgres-server.key`: certificate with `DNS:postgres` SAN, private key readable by the PostgreSQL container's actual service UID.
- `redis-server.crt` / `redis-server.key`: certificate with `DNS:redis` SAN and private key readable by the Redis service UID.

Private keys and the generated `secrets/redis.conf` must remain restricted. On Linux, assign access to the actual image service UIDs, verify modes before startup and validate TLS handshakes. Do not use permissive modes or disable TLS verification to bypass a mismatch. Pin compatible PostgreSQL/Redis image digests before using this overlay.

The database volume is not a backup. Configure off-host encrypted/access-controlled backups and WAL/PITR, then rehearse restoration to an isolated environment. Do not close the recovery launch gate on the strength of these templates.

## Coturn prerequisites

The new API is `GET /api/network/calls/ice`, authenticated with the normal cookie/bearer session. Its response has `Cache-Control: no-store`, `iceServers`, `relayConfigured` and credential expiry metadata. The default local profile retains the existing STUN fallback; production relay-required mode fails closed when its signing configuration is absent.

Provision `turn.myaaptha.com`, its public/private IPv4 mapping and issued TLS certificate/key (`certs/turn-fullchain.pem`, `certs/turn-key.pem`). With owner access to the protected key directory, render once:

```text
python infrastructure/render_turn_config.py --public-ip ASSIGNED_PUBLIC_IPV4 --private-ip ASSIGNED_PRIVATE_IPV4
```

The renderer writes `secrets/turnserver.conf` and refuses to overwrite it. It does not print the signing secret or contact the relay. Coturn credentials follow its documented [temporary HMAC scheme](https://github.com/coturn/coturn/wiki/turnserver).

Use `compose.call-relay.yml` on the Linux instance with an immutable Coturn image. Configure firewall rules for TCP/UDP 3478, TCP 5349 and UDP relay ports 49160–49200. Keep database/cache ports closed publicly. Verify public/private NAT mapping, TLS chain/hostname, allocation limits, abuse controls and network-change behavior. The one-hour credential limit does not establish unlimited call duration or reconnection acceptance.

## Compose validation

After supplying actual immutable image references, bucket, TLS and non-secret deployment settings, engineering can validate the combined profile without displaying configuration values:

```text
docker compose --env-file owner-settings.env -f docker-compose.prod.yml -f compose.single-host.yml -f compose.integrations.yml -f compose.call-relay.yml config --quiet
```

Run from this directory. The actual `owner-settings.env` should be kept outside version control; `owner-settings.env.example` is a template. A successful render is not a live delivery, TLS, capacity, recovery or release acceptance test.

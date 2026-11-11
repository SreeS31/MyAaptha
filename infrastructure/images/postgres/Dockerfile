FROM postgres:17-alpine@sha256:3540c0362c809df084ffac0ae69fe794515f9de92692f02178bcdce0ef0302ac

# The upstream Go-based gosu binary contains vulnerable standard-library code.
# PostgreSQL needs only its privilege-drop behavior; Alpine's su-exec provides it
# without embedding a second language runtime. Preserve the entrypoint contract.
RUN apk upgrade --no-cache \
    && apk add --no-cache su-exec \
    && grep -q 'exec gosu postgres' /usr/local/bin/docker-entrypoint.sh \
    && sed -i 's/exec gosu postgres/exec su-exec postgres/' /usr/local/bin/docker-entrypoint.sh \
    && rm /usr/local/bin/gosu

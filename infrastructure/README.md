# Local identity and TLS foundation

This stack is for the trusted local demonstration only. Phase C configures the backend
introspection/session boundary, realm import, and a narrow signed security-event listener. It does
not implement the Flutter mobile login or establish physical local-CA trust.

## Pinned selections

| Component | Selection | Immutable multi-platform digest | License |
| --- | --- | --- | --- |
| Keycloak | `quay.io/keycloak/keycloak:26.7.0` | `sha256:0f198be292568439d700cdbfb893e69a6009bb43a94a06a945b1d3d506c76b13` | Apache-2.0 |
| Mailpit | `axllent/mailpit:v1.30.0` | `sha256:0059ef81e492a7192af3816281eed6859eb078bd7bdc58b76757c13e10e53a7d` | MIT |
| Caddy | `caddy:2.11.4-alpine` | `sha256:5f5c8640aae01df9654968d946d8f1a56c497f1dd5c5cda4cf95ab7c14d58648` | Apache-2.0 |
| PostgreSQL | `postgres:16.13-alpine` | `sha256:4e6e670bb069649261c9c18031f0aded7bb249a5b6664ddec29c013a89310d50` | PostgreSQL License |
| Alembic | Python package `1.18.5` | locked in `backend/uv.lock` | MIT |

Primary release evidence: [Keycloak downloads](https://www.keycloak.org/downloads),
[Keycloak 26.7.0 release](https://www.keycloak.org/2026/07/keycloak-2670-released),
[Mailpit releases](https://github.com/axllent/mailpit/releases),
[Caddy releases](https://github.com/caddyserver/caddy/releases),
[PostgreSQL 16.13 release](https://www.postgresql.org/docs/release/16.13/), and
[Alembic changelog](https://alembic.sqlalchemy.org/en/latest/changelog.html).

The digests above were resolved from the official registries on August 3, 2026. To update a pin,
review the official release and upgrade notes, inspect the new registry manifest without pulling
or starting it, update the tag and digest together, validate Compose, then run the isolated
migration and tenant-isolation suites.

## Boundaries and persistent data

- Caddy terminates local TLS for the canonical origin `https://192.168.2.44` using its internal
  CA and proxies Keycloak paths without changing the issuer origin.
- Caddy's `/data` volume contains CA and certificate private material. Never export it into the
  repository or test artifacts.
- Keycloak has a separate PostgreSQL service and named volume. It never shares or replaces the
  LockdIn application database volume.
- Mailpit's SMTP port is internal to the Compose network. Only its web UI is bound, on loopback;
  no relay configuration exists. Use synthetic addresses only.
- The Keycloak database and bootstrap-admin passwords are required environment values. Do not use
  the placeholders from `.env.example` as actual credentials.
- The API-client secret and event-webhook secret are separate required environment values. The
  backend CA bundle is an operator-owned read-only mount; never commit CA or private-key material.

## Phase C validation status

The custom event-listener provider compiles and the pinned Keycloak image build succeeds. Compose
configuration validates with synthetic process-only values. With the corrected redirect URI
`com.lockdin.lockdinapp:/oauth2redirect`, a completely disposable, volume-free Keycloak 26.7.0
realm import succeeded and live realm/client/flow/listener assertions passed. This is
process/container evidence only: persistent full-stack startup, Mailpit delivery, physical
Caddy/phone CA trust, Flutter Phase D login, and production readiness remain unverified.

Before starting the stack, make a verified backup of any existing LockdIn database and read the
migration runbook in `database/README.md`. Starting containers and installing the local CA on a
phone are explicit operator actions and are not part of configuration validation.

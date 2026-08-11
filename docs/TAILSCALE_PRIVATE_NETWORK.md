# Private Tailscale development boundary

This runbook configures the LockdIn thesis prototype for one private tailnet. It is not a public
deployment design. Every phone must authenticate to the same tailnet, and the Windows laptop,
Docker Desktop, the LockdIn stack, and Tailscale must remain running. Do not enable Tailscale
Funnel or open the loopback edge, database, backend, Keycloak, Mailpit, or management ports to the
public internet.

## Operator-controlled prerequisites

The operator must complete these actions directly:

1. Install Tailscale on Windows and Android from the official distributions.
2. Sign both devices into the same tailnet.
3. Approve Android's VPN profile.
4. Enable MagicDNS and tailnet HTTPS in the Tailscale admin console or consent page if prompted.
5. Confirm both nodes are online with `tailscale status` and record the Windows node's full
   `*.ts.net` MagicDNS name. Do not commit that real name.

Tailscale installation, authentication, VPN approval, and Android permission changes are never
automated by this repository.

## Local configuration

Copy `.env.tailscale.example` to the ignored `.env.tailscale`. Reuse the existing stack secrets and
set `LOCKDIN_EXTERNAL_ORIGIN` to the exact stable origin, without a trailing slash:

```text
LOCKDIN_EXTERNAL_ORIGIN=https://windows-machine.example-tailnet.ts.net
```

Copy `frontend/flutter_app/.env.sample` to the ignored Flutter `.env` and set the same origin:

```text
LOCKDIN_API_BASE_URL=https://windows-machine.example-tailnet.ts.net
```

For the one-time transition of an already-used app installation, set
`LOCKDIN_LEGACY_KEYCLOAK_ISSUER` to the exact issuer stored by that installation. This value is a
narrow allowlist: it lets the app move only the matching issuer-and-subject binding to the new
issuer while preserving the existing account generation. Remove it from later builds after the
transition is verified.

## Private edge

`docker-compose.tailscale.yml` changes the base stack as follows:

- PostgreSQL and FastAPI have no host-published ports;
- Caddy exposes one HTTP router only on `127.0.0.1:8088` by default;
- Keycloak remains internal and its management port is not published;
- Mailpit remains bound to host loopback; an optional, separate Tailscale Serve route can make its
  web UI available to permitted tailnet devices without exposing it to the LAN or public internet;
- Caddy does not terminate TLS and does not route `/admin/*` to Keycloak;
- the backend reaches Keycloak directly at `http://keycloak:8080`, while token validation retains
  the exact external HTTPS issuer.

Before recreating an existing stack, identify its Compose project and named volumes, take a
verified backup, and confirm the issuer migration plan. Starting under a new project name creates
new volumes and will make existing history appear missing.

Validate the merged Compose model before starting it:

```powershell
docker compose `
  -f docker-compose.yml `
  -f docker-compose.tailscale.yml `
  --env-file .env.tailscale `
  config --quiet
```

After the loopback edge responds at `http://127.0.0.1:8088`, expose only that router to the private
tailnet:

```powershell
tailscale serve --bg http://127.0.0.1:8088
tailscale serve status
tailscale funnel status
```

`tailscale funnel status` must show no Funnel configuration for this service. Tailscale Serve with
background mode persists across Tailscale restarts and machine reboots, but the proxied application
still depends on the local processes being available.

### Optional private Mailpit access

Mailpit captures verification and password-reset bearer links. Keep its Docker port bound to
`127.0.0.1` and use synthetic addresses only. When the phone must open the inbox directly, publish
the loopback UI on a separate tailnet-only HTTPS port:

```powershell
tailscale serve --bg --https=8444 http://127.0.0.1:8025
tailscale serve status
tailscale funnel status
```

Open `https://<machine>.<tailnet>.ts.net:8444/` from a device signed into the permitted tailnet.
Every route in both status outputs must be labeled `tailnet only`; never enable Funnel. Tailscale
access controls apply to Serve, so adding more users or devices to the tailnet can broaden inbox
access unless port `8444` is restricted in the tailnet policy.

Disable only this optional route when phone inbox access is no longer required:

```powershell
tailscale serve --https=8444 off
```

## Issuer transition

Changing the external hostname changes the Keycloak issuer and invalidates existing sessions. The
application database links identities by exact `(issuer, subject)`, and the Android installation
binding uses the same pair. Never let a first login at the new issuer provision a second account.

Before changing identity data:

1. Count source-issuer identities, target-issuer identities, subject conflicts, revoked sessions,
   audit events, accounts, profiles, and usage rows without selecting identifiers.
2. Confirm the target issuer has no conflicting subject row.
3. Back up the application and Keycloak persistent data.
4. Review a transaction that updates only `external_identities.issuer` from the exact old value to
   the exact new value. Historical audit and revoked-session rows remain tied to the issuer that
   produced them.
5. Obtain explicit operator approval before applying the transaction.
6. Rebuild and install the APK in place with the exact legacy issuer allowlist, then complete a
   fresh interactive sign-in for the same Keycloak account.

Do not delete identities, queue rows, usage history, or volumes to work around an issuer mismatch.

## Required verification

Verify and record real results; do not infer physical-device success from automated tests:

- both Windows and Android nodes are online in the same tailnet;
- the full MagicDNS name resolves on Android and presents a trusted HTTPS certificate;
- the API health route and OIDC discovery work through the stable origin;
- discovery and issued tokens use the exact new issuer;
- the backend accepts only that issuer and the `lockdin-api` audience;
- AppAuth redirects to LockdIn and `/api/v1/auth/session` succeeds;
- the existing account, profile, usage history, and local queue generation are preserved;
- usage synchronization and token renewal succeed;
- USB disconnection does not break connectivity;
- switching the phone between two networks requires no IP edit, reverse rule, or APK rebuild;
- if private Mailpit access is enabled, its HTTPS UI works from Android while Docker remains bound
  to `127.0.0.1:8025` and Funnel remains disabled;
- `tailscale serve status` remains configured after a Tailscale or machine restart;
- Accessibility is disabled and unbound after testing, while Usage Access retains its prior state.

## Primary references

- [Install Tailscale on Windows](https://tailscale.com/docs/install/windows)
- [Install Tailscale on Android](https://tailscale.com/docs/install/android)
- [MagicDNS](https://tailscale.com/docs/features/magicdns)
- [Tailscale Serve CLI](https://tailscale.com/docs/reference/tailscale-cli/serve)
- [Enable tailnet HTTPS](https://tailscale.com/docs/how-to/set-up-https-certificates)
- [Keycloak hostname configuration](https://www.keycloak.org/server/hostname)
- [Keycloak reverse-proxy configuration](https://www.keycloak.org/server/reverseproxy)

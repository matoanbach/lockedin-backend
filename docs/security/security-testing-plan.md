# LockedIn Security Testing Plan

| Field | Value |
|---|---|
| Version | 0.2 (Review Candidate) |
| Date | 2026-07-17 |
| Status | Draft for team review |
| System baseline | Git commit `15d1c57` |

## 1. Purpose

This plan defines how the LockedIn team will identify, test, report, and retest security and privacy risks across the FastAPI backend, Android client, PostgreSQL database, container image, Kubernetes manifests, and Jenkins delivery pipeline.

This document is a testing plan, not proof that a control exists and not a penetration-test report. Items described as **verified gaps** were confirmed by source review at the baseline commit. Items described as **risks** remain hypotheses until a test produces evidence.

The plan uses:

- [OWASP ASVS 5.0](https://owasp.org/www-project-application-security-verification-standard/) for backend security requirements.
- [OWASP WSTG 4.2](https://owasp.org/www-project-web-security-testing-guide/) for repeatable web/API test procedures.
- [OWASP MASVS and MASTG](https://mas.owasp.org/MASVS/) for Android storage, network, platform, privacy, and resilience testing.
- [NIST SP 800-218 SSDF](https://csrc.nist.gov/pubs/sp/800/218/final) for integrating security work into the development lifecycle.

Legal and regulatory obligations are outside this plan's authority. Privacy requirements must be confirmed with the project owner and, where necessary, qualified legal or institutional guidance.

## 2. Scope and Rules of Engagement

### 2.1 In scope

- `backend/src/lockedin_backend/`: API routes, schemas, services, repositories, settings, and error handling.
- `frontend/flutter_app/`: Flutter code and Android-native usage/accessibility integration.
- `backend/Dockerfile` and `backend/conf/gunicorn.conf.py`.
- `k8s/` and `argocd/` deployment configuration.
- `Jenkinsfile` and software-supply-chain controls.
- PostgreSQL schema, data isolation, retention behavior, backups, and secret use.
- Privacy and abuse cases involving usage history and accountability contacts.

### 2.2 Out of scope unless separately authorized

- Destructive testing against production.
- Denial-of-service or load testing against shared infrastructure.
- Social engineering of real people.
- Testing third-party services beyond their published policies and the team's authorization.
- Collection of real credentials, real contact email addresses, or real usage history for test evidence.

### 2.3 Authorized environment

Active testing must use an isolated staging environment with synthetic accounts and data. The tester must record the Git commit, Android build variant/version, container digest, deployment configuration, base URL, test window, and approving person before testing begins.

SQLMap, high-volume fuzzing, brute-force simulation, TLS enumeration, and destructive database cases require explicit approval for that test window. Stop testing if data crosses environment boundaries, availability degrades unexpectedly, secrets appear in output, or the observed target differs from the approved target.

### 2.4 Evidence handling

- Redact tokens, passwords, email addresses, device identifiers, and usage data.
- Store sanitized plans and summaries in the repository.
- Store raw proxy captures, exploit details, scanner reports, and screenshots in access-controlled CI artifacts or a private security tracker.
- Record tool name/version, command or configuration, timestamp, target build, expected result, actual result, and evidence location.
- Delete temporary test data and revoke test credentials after the test window.

## 3. Decision Traceability

Security decisions in this plan use stable identifiers. Each decision records its rationale, evidence, trade-offs, and review trigger. A decision that changes system architecture should later be copied into a dedicated Architecture Decision Record (ADR), while this plan retains the decision ID and ADR link.

| Decision | Decision and rationale | Alternatives/trade-offs | Verification or review trigger |
|---|---|---|---|
| SEC-DEC-001 | Use ASVS/WSTG for the API and MASVS/MASTG for Android. The system has both API and mobile attack surfaces, so one checklist would leave material gaps. | A custom-only checklist is shorter but harder to defend, repeat, and maintain. | Review when adopting a new major standard version or changing a platform. |
| SEC-DEC-002 | Do not prescribe a JWT library or custom login yet. Identity provider, first-party accounts, tenant boundaries, token lifecycle, recovery, and revocation must be designed first. | A quick custom JWT implementation is faster initially but risks embedding the wrong identity and tenancy model. | Create an ADR before authentication implementation. |
| SEC-DEC-003 | Treat the current authorization issue as unauthenticated shared-profile access, not IDOR. Call it IDOR only after user-controllable object references and ownership boundaries exist. | Keeping the IDOR label is familiar but technically inaccurate and leads to invalid tests. | Review after multi-user/profile isolation is implemented. |
| SEC-DEC-004 | Use the 5x5 matrix for project risk prioritization and CVSS only for confirmed technical vulnerabilities when useful. | Mapping the matrix directly to CVSS appears precise but combines two different models. | Re-score when exposure, controls, or impact changes. |
| SEC-DEC-005 | Enforce request limits in layers: ingress/reverse proxy for raw body size and rate controls, ASGI/application controls for API behavior, and schema controls for fields and collections. | Schema-only validation happens after request parsing; proxy-only controls lack business context. Gunicorn has no `limit_request_body` setting. | Verify each layer in staging after deployment configuration exists. |
| SEC-DEC-006 | Require valid HTTPS and platform certificate validation for release traffic. Certificate pinning is optional and requires a documented threat model, backup pins, and a safe rotation/recovery procedure. | Pinning can narrow CA trust but can also cause outages during certificate or key rotation. | Revisit if the app handles higher-impact secrets or the network threat model changes. |
| SEC-DEC-007 | Assess Android private storage by data sensitivity and attacker preconditions rather than calling all plaintext private storage a vulnerability. | Encrypting every local value increases key-management and recovery complexity without always reducing realistic risk. | Revisit after the data inventory and backup/rooted-device tests. |
| SEC-DEC-008 | Keep sanitized plans in Git and sensitive findings outside the public repository. | Centralizing all evidence in Git is convenient but can permanently expose secrets, PII, and exploit details. | Review repository visibility and artifact retention at each release. |
| SEC-DEC-009 | Use a supported secret-delivery mechanism and least-privilege access. Kubernetes `stringData` is not itself a vulnerability; committed weak values and unencrypted or overly broad secret access are. | Sealed Secrets, External Secrets, and platform-managed solutions have different operational costs. Selection belongs in a deployment ADR. | Review when the production cluster and secret owner are known. |
| SEC-DEC-010 | Treat privacy export, deletion, consent, and retention as product/legal requirements to validate, not universal endpoint prescriptions. | Hard-coding a specific API or 90-day period without an approved requirement can implement the wrong policy. | Review after a data inventory, owner decision, and applicable-law assessment. |

For new decisions, add a row above with this minimum evidence:

1. The risk or requirement being addressed.
2. Repository or test evidence supporting the decision.
3. Alternatives considered and their trade-offs.
4. How the team will verify the decision.
5. The condition or date that causes reconsideration.

## 4. Current Security Baseline

### 4.1 Verified controls

- Pydantic validates API request models server-side.
- Usage ingestion is limited to 100 events and a modeled payload of 128 KiB per request.
- Usage events are constrained by duration, age, future-time tolerance, and same-app overlap rules.
- SQLAlchemy ORM is used for backend database access; no backend raw SQL execution was found in the reviewed paths.
- Usage events have a profile/source-event uniqueness constraint for idempotency.
- Default CORS configuration is limited to localhost and `127.0.0.1`; CORS is not treated as authentication.
- Android cleartext traffic is enabled only in the debug manifest; release builds retain Android's default cleartext restriction.
- The accessibility service is non-exported and protected by `BIND_ACCESSIBILITY_SERVICE`.
- Android queues and preferences use application-private storage rather than shared external storage.
- No file-upload or backend OS-command execution surface was found.
- Python application dependencies are version-pinned, although no automated vulnerability audit is configured.

### 4.2 Verified control gaps

- API routes have no authentication or authorization dependency and operate on a default shared profile.
- Development database credentials are present in the default database URL, and Kubernetes database credential configuration is inconsistent with that URL.
- Debug mode defaults to enabled; OpenAPI, Swagger UI, and ReDoc are always mounted.
- Kubernetes ingress does not configure TLS or a production host.
- No general raw request-body limit or request-rate control is configured.
- The container does not declare a non-root runtime user.
- Kubernetes workloads lack documented pod/container security contexts, resource limits, health probes, and NetworkPolicies.
- The backend deployment uses mutable image tag `latest` with `imagePullPolicy: Always`.
- Jenkins builds and pushes the image but does not run unit tests, SAST, dependency audits, secret scanning, IaC scanning, or container scanning.
- No documented production backup encryption, retention enforcement, incident response procedure, or security monitoring was found.

### 4.3 Facts requiring environment validation

- Whether the ingress is internet-accessible.
- Whether TLS is terminated by infrastructure outside this repository.
- Whether Kubernetes Secrets are encrypted at rest and access is restricted.
- Whether persistent volumes and backups are encrypted.
- Whether API documentation is restricted by an external gateway.
- Whether production logs or monitoring exist outside the repository.

## 5. Risk Scoring

Risk score = Likelihood x Impact. Scores are prioritization aids, not probability measurements or delivery deadlines.

### 5.1 Likelihood

| Score | Level | Meaning |
|---:|---|---|
| 5 | Almost certain | Expected during normal operation or trivially repeatable by an applicable threat actor. |
| 4 | Likely | Credible and easy to execute with few preconditions. |
| 3 | Possible | Credible but requires access, timing, knowledge, or another precondition. |
| 2 | Unlikely | Requires uncommon access or multiple significant preconditions. |
| 1 | Rare | Requires exceptional conditions and has little supporting evidence. |

### 5.2 Impact

| Score | Level | Meaning |
|---:|---|---|
| 5 | Critical | Broad compromise, serious safety/privacy harm, or loss of system trust. |
| 4 | High | Significant unauthorized data access/change or major service disruption. |
| 3 | Medium | Limited data exposure/change or recoverable service disruption. |
| 2 | Low | Small, contained effect with straightforward recovery. |
| 1 | Negligible | No meaningful security or privacy effect. |

### 5.3 Risk levels

| Score | Level | Required treatment |
|---:|---|---|
| 20-25 | Critical | Block production release unless remediated or explicitly accepted by the accountable owner. |
| 12-19 | High | Assign an owner and target release; test before production release. |
| 6-11 | Medium | Track and schedule according to exposure and available controls. |
| 1-5 | Low | Track if useful; address through normal hardening. |

Risk acceptance must identify the owner, rationale, compensating controls, expiry/review date, and residual risk. Remediation timelines are set by the team after considering exposure and release plans.

## 6. Risk Register

Scores are provisional until the deployment facts in Section 4.3 are resolved.

| ID | Risk scenario | L | I | Score | Basis and mapped tests |
|---|---|---:|---:|---:|---|
| T1 | An unauthenticated caller reads or changes rules, preferences, contacts, usage-derived analytics, or enforcement data if the API is reachable. | 5 | 5 | 25 | Verified gap; AUTH-01, AUTH-02. |
| T2 | Multiple users are mapped to the same default profile, causing cross-user disclosure or modification. | 4 | 5 | 20 | Verified architecture; AUTH-03, DATA-01. |
| T3 | Default, committed, or inconsistently provisioned database credentials permit unauthorized database access. | 4 | 5 | 20 | Verified configuration gap; DEP-03, CICD-02. |
| T4 | Traffic is intercepted or modified where the deployment lacks correctly configured TLS. | 4 | 5 | 20 | Ingress gap; NET-01 through NET-04, MOB-NET-01. |
| T5 | Crafted input alters a database query or exposes error details. | 2 | 4 | 8 | ORM is a control; validate actual endpoints with INP-01 through INP-04. |
| T6 | User-controlled content executes in a future browser/HTML consumer. | 1 | 3 | 3 | No current HTML rendering sink found; INP-05 is a regression check. |
| T7 | Repeated or oversized requests exhaust API, worker, or database resources. | 3 | 4 | 12 | Some usage limits exist, but no general body/rate/resource controls; AVAIL-01 through AVAIL-04. |
| T8 | Debug behavior or public API documentation discloses internal details in production. | 4 | 3 | 12 | Verified defaults; CONF-01 through CONF-03. |
| T9 | Usage history or contact email data is exposed through database, backup, log, or device extraction. | 3 | 4 | 12 | Infrastructure facts unknown; DATA-01 through DATA-05, MOB-STOR-01. |
| T10 | A vulnerable or malicious dependency, container layer, or mutable image compromises a build or deployment. | 3 | 4 | 12 | No automated audit and mutable tag; SUP-01 through SUP-05. |
| T11 | CI/CD credentials or pipeline permissions are abused to publish an unauthorized image. | 3 | 5 | 15 | Pipeline impact is high; CICD-01 through CICD-04. |
| T12 | Root container execution or weak Kubernetes isolation amplifies a workload compromise. | 3 | 4 | 12 | Verified hardening gaps; DEP-01 through DEP-05. |
| M1 | A rooted, backed-up, debugged, or physically accessed device exposes sensitive cached usage or rule data. | 2 | 4 | 8 | App-private storage is a control; MOB-STOR-01 through MOB-STOR-04. |
| M2 | Release traffic accepts an invalid endpoint identity or unexpectedly permits cleartext. | 2 | 4 | 8 | Release default is a control; MOB-NET-01 through MOB-NET-03. |
| M3 | Reverse engineering reveals an embedded secret or enables unsafe endpoint substitution. | 3 | 2 | 6 | Endpoints are not secrets; future credentials must not be embedded; MOB-RES-01, MOB-RES-02. |
| M4 | Accessibility privileges or device-time/reinstall manipulation bypass intended enforcement or collect more information than necessary. | 4 | 4 | 16 | High-privilege product surface; MOB-PLAT-01 through MOB-PLAT-05. |
| H1 | An abusive person uses accountability features to control or monitor another person. | 3 | 5 | 15 | Product abuse case; PRIV-01 through PRIV-04. |
| H2 | App-usage patterns reveal sensitive interests, health, relationship, or behavioral information. | 4 | 4 | 16 | Inherent data sensitivity; PRIV-05 through PRIV-08. |
| H3 | A person is added or impersonated as an accountability contact without meaningful verification or consent. | 3 | 4 | 12 | Current contact model requires design review; PRIV-02 through PRIV-04. |
| H4 | A user bypasses enforcement through reinstall, multiple profiles, clock changes, permission revocation, or force-stop. | 4 | 2 | 8 | Expected client-side adversarial behavior; MOB-PLAT-02 through MOB-PLAT-05. |
| H5 | Contact emails are harvested or reused for phishing. | 2 | 3 | 6 | Depends on API exposure and notification design; DATA-02, PRIV-04. |
| H6 | A security event is not detected, contained, or communicated because response ownership and monitoring are undefined. | 4 | 4 | 16 | Verified documentation gap; OPS-01 through OPS-04. |

## 7. Test Strategy and Tooling

Tools support testing; their output is not automatically a confirmed finding. Tool versions and rulesets must be pinned or recorded so results are reproducible.

| Technique/tool | Purpose | Decision rationale | Execution |
|---|---|---|---|
| Unit/integration tests | Verify authorization, validation, limits, and negative cases close to the code. | Fast, deterministic tests should be the first security gate. | Every pull request. |
| Bandit | Python-focused SAST. | Detects common Python security patterns but requires human triage. | Every pull request; archive SARIF/JSON. |
| `pip-audit` | Audit Python dependencies against known advisories. | PyPA-maintained and suitable for Python projects and lock/project files. | Every pull request and scheduled refresh. |
| Trivy | Scan container vulnerabilities, secrets, and Kubernetes/IaC misconfiguration. | Covers multiple repository surfaces with one tool; results still require triage. | Pull request for config; built image before publish. |
| Gitleaks or equivalent | Detect committed secrets and high-entropy credentials. | Dependency scanning does not find repository secret exposure. | Pull request and full-history baseline scan. |
| OWASP ZAP baseline/API scan | Automated DAST against the deployed OpenAPI surface. | Repeatable coverage of deployed behavior and headers. | Authorized staging; never production by default. |
| Burp Suite | Manual proxying, authorization checks, and workflow manipulation. | Business logic and abuse cases require human judgment. | Authorized staging test window. |
| SQLMap | Targeted confirmation of suspected SQL injection only. | Broad automated exploitation is noisy and can damage data; ORM review and harmless manual probes come first. | Isolated staging only with explicit approval. |
| Flutter/Dart analysis and tests | Detect client regressions and validate release behavior. | Mobile controls cannot be inferred solely from backend tests. | Every pull request. |
| Manual Android testing | Inspect manifests, storage, backups, logs, traffic, permissions, and tampering. | MASVS platform and privacy behavior requires a real/emulated device and runtime evidence. | Before release and after platform-sensitive changes. |

Recommended CI order:

1. Existing backend and frontend tests.
2. SAST, secret scan, and dependency audits.
3. Build an immutable image identified by commit SHA/digest.
4. Scan the built image and deployment manifests.
5. Publish only after required gates pass.
6. Deploy that exact digest to isolated staging.
7. Run authorized DAST and manual release testing.

Do not install unpinned `latest` scanner versions inside each pipeline run. Pin tool/container versions and schedule deliberate updates.

## 8. Test Cases

### 8.1 Authentication and authorization

Authentication tests marked **design-gated** become runnable only after SEC-DEC-002 has an approved identity/tenancy ADR.

| ID | Test | Expected result | Current state |
|---|---|---|---|
| AUTH-01 | Call every protected endpoint without credentials. | Request is rejected consistently; only explicitly public health/bootstrap endpoints remain accessible. | Baseline expected to fail. |
| AUTH-02 | Use missing, malformed, expired, revoked, wrong-audience, and wrong-issuer credentials. | Rejected without sensitive error detail. | Design-gated. |
| AUTH-03 | Attempt read/update/delete using identifiers owned by a second synthetic user. | Denied at the service/repository boundary; no cross-tenant existence leak. | Design-gated; current shared-profile model fails isolation objective. |
| AUTH-04 | Modify object/profile identifiers in paths, bodies, and query parameters. | Server derives or verifies ownership rather than trusting the client. | Design-gated. |
| AUTH-05 | Exercise login, recovery, refresh, logout, and credential-revocation abuse cases. | Rate controls, session invalidation, audit events, and non-enumerating responses match the approved design. | Design-gated. |

If passwords are selected, follow the approved identity assurance target. At minimum, test adequate length, acceptance of password-manager/passphrase input, compromised/common-password blocking, secure password hashing, safe recovery, and rate limiting. Do not require arbitrary mixtures of uppercase, lowercase, numbers, and symbols merely as a complexity rule; see [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html).

### 8.2 Input validation and injection

Build the endpoint inventory from the baseline OpenAPI document rather than using invented parameters.

| ID | Test | Expected result |
|---|---|---|
| INP-01 | Submit quotes, SQL metacharacters, Unicode, control characters, null-like values, and boundary lengths to actual string fields. | Data is safely rejected or stored as data; no query behavior change or stack trace. A quote is not rejected solely because it resembles SQL. |
| INP-02 | Test missing, extra, wrong-type, zero, negative, and over-bound numeric/date/time values. | Stable 4xx response with no partial write. |
| INP-03 | Test duplicate IDs, replayed `source_event_id`, overlapping events, DST boundaries, invalid time zones, stale events, and future timestamps. | Documented idempotent/validation behavior with no aggregate corruption. |
| INP-04 | Test maximum allowed events and modeled payload, then one unit above each limit. | Boundary accepted; over-limit rejected without resource exhaustion or partial write. |
| INP-05 | Put HTML/script-like text into stored string fields and inspect all current clients/response content types. | JSON remains JSON and no client executes the content. |
| INP-06 | Verify there are no unreviewed raw SQL, shell, file-path, template, or deserialization sinks. | No unsafe sink; any new sink has targeted tests. |

### 8.3 Availability and request controls

| ID | Test | Expected result |
|---|---|---|
| AVAIL-01 | Send a raw request body over the ingress/application limit. | Rejected before expensive application processing. |
| AVAIL-02 | Burst and sustain requests per IP, device, account, and sensitive operation. | Approved limits produce predictable 429 behavior without blocking normal use. |
| AVAIL-03 | Repeat aggregate rebuild and expensive analytics operations concurrently. | Protected by authorization and operation-specific limits; database remains responsive. |
| AVAIL-04 | Exhaust worker timeouts/connections in isolated load testing. | Service degrades predictably, recovers, and produces actionable telemetry. |

### 8.4 Configuration, network, and data protection

| ID | Test | Expected result |
|---|---|---|
| CONF-01 | Start the production configuration without an explicit debug setting. | Debug is off by default or production startup fails closed. |
| CONF-02 | Request Swagger UI, ReDoc, OpenAPI, debug, and error endpoints in production mode. | Exposure matches an approved decision; errors do not reveal internals. |
| CONF-03 | Review CORS against actual browser clients. | Only required origins/methods/headers are allowed; CORS is not relied on for API authorization. |
| NET-01 | Connect through the production-equivalent hostname over HTTP. | Redirected safely to HTTPS or refused. |
| NET-02 | Validate certificate chain, hostname, expiry, protocols, and cipher configuration. | Valid identity and approved modern TLS configuration. |
| NET-03 | Check HSTS and proxy forwarding behavior at the actual TLS termination point. | Headers and scheme handling are correct and cannot be spoofed by untrusted clients. |
| NET-04 | Inspect internal service/database reachability. | Only required workloads and operators can connect. |
| DATA-01 | Verify every persistent record is scoped to the intended user/profile. | No shared or orphaned ownership; database constraints support application checks. |
| DATA-02 | Search application, proxy, CI, and cluster logs for secrets and sensitive usage/contact data. | Sensitive values are absent or deliberately redacted. |
| DATA-03 | Verify database volume and backup encryption, access controls, restore tests, and key ownership. | Controls match the approved data classification and recovery plan. |
| DATA-04 | Exercise approved retention and deletion rules. | Raw events, aggregates, contacts, backups, and derived data follow the same documented lifecycle. |
| DATA-05 | Exercise approved export/correction/deletion workflows with synthetic data. | Complete, authenticated, auditable, and resistant to cross-user access. |

### 8.5 Android/mobile

| ID | Test | Expected result |
|---|---|---|
| MOB-NET-01 | Run a release build against cleartext HTTP and an invalid/untrusted certificate. | Connection fails safely; no silent downgrade. |
| MOB-NET-02 | Inspect release traffic and logs for sensitive data. | Only necessary fields are transmitted; secrets and sensitive payloads are not logged. |
| MOB-NET-03 | If pinning is approved, rotate to primary/backup pins and simulate recovery. | No avoidable outage and no bypass to trust-all behavior. |
| MOB-STOR-01 | Inventory SQLite, SharedPreferences, files, caches, screenshots, notifications, and logs. | Stored data matches the classification and minimization decisions. |
| MOB-STOR-02 | Test Android backup/data-extraction behavior for the release manifest. | Sensitive data is excluded or protected according to the approved backup policy. |
| MOB-STOR-03 | Test uninstall/reinstall, logout/account change, and queue cleanup. | Data is removed or migrated according to documented lifecycle rules. |
| MOB-STOR-04 | Attempt extraction on debug, rooted, or physically controlled test devices. | Residual risk and attacker preconditions are documented; approved protection works. |
| MOB-RES-01 | Inspect the release APK for embedded credentials, signing mistakes, debug flags, endpoints, and excessive metadata. | No secret is embedded; public configuration is treated as public. |
| MOB-RES-02 | Tamper with endpoint/configuration and replay queued events. | Server-side authentication, validation, idempotency, and ownership checks contain impact. |
| MOB-PLAT-01 | Review permissions, exported components, intent filters, and accessibility configuration. | Least privilege; only the launcher is intentionally exported; privileged-service behavior is justified. |
| MOB-PLAT-02 | Revoke usage/accessibility permission during enforcement and upload. | Clear user state, safe failure, no hidden collection, and no crash loop. |
| MOB-PLAT-03 | Change device time/time zone across DST and future/past extremes. | No bypass, duplicate charge, corrupt aggregate, or unsafe queue growth. |
| MOB-PLAT-04 | Force-stop, reboot, update, and reinstall during active rules and queued uploads. | Behavior matches documented product guarantees; bypass limitations are transparent. |
| MOB-PLAT-05 | Use work profiles, multiple users, cloned apps, split-screen, and rapid foreground changes where supported. | Enforcement scope and limitations are documented and tested. |

### 8.6 Privacy and abuse cases

| ID | Test | Expected result |
|---|---|---|
| PRIV-01 | Map every collected field from device to API, database, analytics, logs, backup, and deletion path. | Each field has purpose, owner, sensitivity, retention, access, and deletion decisions. |
| PRIV-02 | Attempt to add or substitute an accountability contact without that person's approved verification/consent flow. | Prevented or explicitly constrained by the approved product model. |
| PRIV-03 | Test revocation, blocking, relationship changes, and emergency disengagement. | Affected people can safely end participation without hidden continued monitoring. |
| PRIV-04 | Review notifications/messages for impersonation, phishing, enumeration, and disclosure. | Sender/purpose are clear; content is minimized; errors do not enumerate contacts. |
| PRIV-05 | Infer sensitive behavior from raw events, aggregates, app names/categories, timestamps, and contact associations. | Collection and display are minimized to the documented purpose. |
| PRIV-06 | Test analytics with sparse data and unusual apps/categories. | No unintended disclosure or misleading sensitive inference. |
| PRIV-07 | Verify consent/disclosure text and operating-system permission prompts against actual collection behavior. | Plain-language explanation precedes collection; revocation is respected. |
| PRIV-08 | Verify retention, export, correction, and deletion decisions with product/legal owners. | Requirements and evidence are recorded without claiming unsupported legal conclusions. |

### 8.7 Supply chain, deployment, CI/CD, and operations

| ID | Test | Expected result |
|---|---|---|
| SUP-01 | Audit resolved Python and Flutter/Dart dependency sets for known advisories. | Findings are triaged; accepted exceptions have owner and expiry. |
| SUP-02 | Scan the built container, source tree, and manifests. | No unaccepted critical/high vulnerability, secret, or material misconfiguration. |
| SUP-03 | Generate and retain an SBOM tied to the image digest. | Deployed components can be traced to the exact build. |
| SUP-04 | Verify dependencies, base images, and CI tools are pinned and deliberately updated. | Builds are reproducible and do not silently consume mutable `latest` artifacts. |
| SUP-05 | Verify image provenance/signature policy if adopted. | Cluster deploys the intended image from the approved pipeline. |
| CICD-01 | Review repository, Jenkins, registry, and cluster permissions. | Least privilege, protected branches, peer review, and separation of duties. |
| CICD-02 | Verify credentials are masked, scoped, rotated, and unavailable to untrusted pull requests. | No secret appears in logs or attacker-controlled jobs. |
| CICD-03 | Attempt to publish/deploy after a required test or scan fails. | Pipeline blocks publication/deployment and records the reason. |
| CICD-04 | Trace a deployment to commit, build, scan results, SBOM, image digest, and approver. | Complete auditable chain. |
| DEP-01 | Inspect container user, capabilities, filesystem permissions, and writable paths. | Non-root, least privilege, and only required paths writable. |
| DEP-02 | Validate security contexts, resource requests/limits, probes, and disruption behavior. | Workload fails and recovers safely within approved limits. |
| DEP-03 | Inspect secret manifests and runtime values without recording secret contents. | No real/weak credential in Git; values are consistent and access-controlled. |
| DEP-04 | Review Kubernetes RBAC and NetworkPolicies. | Workloads and operators have only required API/network access. |
| DEP-05 | Verify image digest use and rollback. | Deployment is immutable, attributable, and safely reversible. |
| OPS-01 | Simulate detection and triage of repeated auth failures, unusual ingestion, and privilege/config changes. | Actionable alert reaches a named owner. |
| OPS-02 | Tabletop a credential leak and unauthorized data access. | Containment, rotation, evidence preservation, communication, and recovery steps work. |
| OPS-03 | Verify security contact and vulnerability-reporting process. | Reporter can reach the team without publicly disclosing sensitive details. |
| OPS-04 | Review log retention, time synchronization, access, and redaction. | Evidence is useful, protected, and retained only as approved. |

## 9. Entry, Exit, and Release Criteria

### Entry criteria

- Written authorization and named tester.
- Isolated target with synthetic data.
- Exact build/configuration recorded.
- Current endpoint and data-flow inventories.
- Backup/rollback and cleanup plan for state-changing tests.
- Monitoring available during higher-impact tests.

### Exit criteria

- Planned tests have a pass, fail, blocked, or not-applicable disposition with rationale.
- Evidence is stored and redacted according to Section 2.4.
- Confirmed findings have severity, owner, target, and retest criteria.
- Test-created data and credentials are removed or revoked.
- Residual risks and untested scope are stated explicitly.

### Minimum production release gate

- No unresolved critical risk unless explicitly accepted by the accountable owner.
- Authentication and tenant isolation pass if the deployment is shared or externally reachable.
- HTTPS and production secret handling are verified in the actual deployment path.
- Existing functional tests, security unit/integration tests, SAST, dependency, secret, IaC, and built-image scans pass their approved thresholds.
- High findings have an owner and approved treatment before release.
- The exact image digest tested is the image selected for deployment.

## 10. Finding, Retest, and Risk-Acceptance Workflow

Do not label scanner output as a vulnerability until it is reproduced or otherwise validated.

```markdown
# [FINDING-ID] Title

- Status: Candidate | Confirmed | Fixed pending retest | Closed | Accepted
- Project risk: Likelihood x Impact = score
- CVSS: Optional; include version/vector only for an applicable confirmed technical vulnerability
- Affected build/component:
- Mapped risk/test/standard:
- Owner and target:

## Description and preconditions

## Reproduction steps

## Expected versus actual result

## Impact and data affected

## Evidence location and redactions

## Recommended control and rationale

## Retest procedure

## Residual risk or acceptance
```

Retest workflow:

1. Developer links the fix and identifies the exact staging build.
2. Tester repeats the original case and relevant regression cases.
3. Tester records actual evidence and confirms no partial bypass remains.
4. Finding is closed, reopened, or moved to documented risk acceptance.
5. Any temporary diagnostic control or test credential is removed.

## 11. Prioritized Security Work

This is a decision backlog, not authorization to implement a particular package or architecture.

### Phase 0: Confirm architecture and exposure

- [ ] Record whether the API/ingress is public and where TLS terminates.
- [ ] Approve identity, account recovery, device/client, session, and tenant-isolation architecture (SEC-DEC-002).
- [ ] Complete the usage/contact data inventory and privacy requirements (SEC-DEC-010).
- [ ] Assign security finding, incident response, deployment, and risk-acceptance owners.

### Phase 1: Production blockers

- [ ] Implement and test authentication/authorization and database-backed tenant isolation if the service is shared or reachable.
- [ ] Configure and verify HTTPS across the real client-to-termination path.
- [ ] Remove weak/default production credentials and adopt approved secret delivery.
- [ ] Disable production debug behavior and make API documentation exposure an explicit decision.
- [ ] Run the application container as non-root and establish baseline Kubernetes isolation/resources/probes.
- [ ] Make CI run functional and minimum security gates before publishing an immutable image.

### Phase 2: Defense in depth and privacy

- [ ] Add layered body-size, rate, and expensive-operation controls based on measured legitimate traffic.
- [ ] Add secret, dependency, SAST, IaC, container, and SBOM checks with triage ownership.
- [ ] Implement and test the approved retention, deletion, export, consent, and accountability-contact model.
- [ ] Add security telemetry, incident runbooks, and tabletop exercises.
- [ ] Complete Android backup, storage, permission, accessibility, tampering, and network testing.

### Phase 3: Independent validation

- [ ] Run ZAP against authorized staging using the actual OpenAPI inventory.
- [ ] Conduct manual authorization, business-logic, privacy, and abuse-case testing.
- [ ] Use targeted SQLMap testing only if review or harmless probes indicate a plausible injection sink.
- [ ] Retest confirmed fixes against the exact candidate image and Android release build.

## 12. Review and Maintenance

Review this plan at least once per release that changes authentication, stored data, accessibility/usage behavior, deployment exposure, or CI/CD. Also review after a security incident, a material finding, a major dependency/platform change, or a change in applicable privacy requirements.

At each review, update the baseline commit, deployment facts, risk scores, test inventory, decision records, owners, and unresolved scope. Historical findings and decision records must remain traceable even when tests are replaced.

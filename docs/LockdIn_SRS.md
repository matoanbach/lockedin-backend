**LockdIn**

**Software Requirements Specification (SRS)**

[**1. Introduction**](#introduction) **4**

> [1.1 Purpose](#purpose) 4
>
> [1.2 Intended Audience](#intended-audience) 4
>
> [1.3 Scope](#scope) 4
>
> [1.4 Definitions, Acronyms,
> Abbreviations](#definitions-acronyms-abbreviations) 5

[**2. Overall Description**](#overall-description) **5**

> [2.1 Product Perspective](#product-perspective) 5
>
> [2.2 System Interfaces](#system-interfaces) 5
>
> [2.3 User Classes and
> Characteristics](#user-classes-and-characteristics) 5
>
> [2.4 Operating Environment](#operating-environment) 6
>
> [2.5 Constraints and Assumptions](#constraints-and-assumptions) 6
>
> [2.6 Assumptions and dependencies](#assumptions-and-dependencies) 6

[**3. System Features**](#system-features) **6**

> [3.1 FR-1: User Registration and
> Login](#fr-1-user-registration-and-login) 6
>
> [3.2 FR-2: App Usage Monitoring and Event
> Ingestion](#fr-2-app-usage-monitoring-and-event-ingestion) 6
>
> [3.3 FR-3: Lockdown Mechanism (Android Hard
> Locks)](#fr-3-lockdown-mechanism-android-hard-locks) 7
>
> [3.4 FR-4: Soft Lock /Reminders (IOS)](#fr-4-soft-lock-reminders-ios)
> 7
>
> [3.5 FR-5: Rule Configuration and
> Management](#fr-5-rule-configuration-and-management) 7
>
> [3.6 FR-6: Analytics and Dashboard](#fr-6-analytics-and-dashboard) 7
>
> [3.7 FR-7: Notification and Tone
> Profiles](#fr-7-notification-and-tone-profiles) 8
>
> [3.8 FR-8: Accountability Contacts and
> Reporting](#fr-8-accountability-contacts-and-reporting) 8
>
> [3.9 FR-9: Settings, Export, and Privacy
> Controls](#fr-9-settings-export-and-privacy-controls) 8
>
> [3.10 FR-10: Background Jobs and Scheduled
> Summaries](#fr-10-background-jobs-and-scheduled-summaries) 8

[**4. External Interface
Requirements**](#external-interface-requirements) **9**

> [4.1 User Interfaces](#user-interfaces) 9
>
> [4.2 APIs](#apis) 9
>
> [4.3 Hardware Interfaces](#hardware-interfaces) 9
>
> [4.4 Communication Interfaces](#communication-interfaces) 9

[**5. Non-functional Requirements**](#non-functional-requirements) **9**

> [5.1 Performance](#performance) 9
>
> [5.2 Reliability & Availability](#reliability-availability) 10
>
> [5.3 Security & Privacy](#security-privacy) 10
>
> [5.4 Usability & Accessibility](#usability-accessibility) 10
>
> [5.5 Portability & Compatibility](#portability-compatibility) 10
>
> [5.6 Maintainability & Testability](#maintainability-testability) 10
>
> [5.7 Scalability](#scalability) 10

[**6. Data Requirements**](#data-requirements) **11**

> [Data elements](#data-elements) 11
>
> [Retention & anonymization:](#retention-anonymization) 11

[**7. Use Cases**](#use-cases) **11**

> [Use Case UC-01: Onboard & Grant
> Permissions](#use-case-uc-01-onboard-grant-permissions) 11
>
> [Use Case UC-02: Create Lockdown
> Rule](#use-case-uc-02-create-lockdown-rule) 11
>
> [Use Case UC-03: Usage Event
> Ingestion](#use-case-uc-03-usage-event-ingestion) 12
>
> [Use Case UC-04: Evaluate Limits &
> Enforce](#use-case-uc-04-evaluate-limits-enforce) 12
>
> [Use Case UC-05: Send Accountability
> Report](#use-case-uc-05-send-accountability-report) 12

[**8. Work Breakdown Structure**](#work-breakdown-structure) **13**

> [1. Project Management &
> Documentation](#project-management-documentation) 13
>
> [2. Requirements & Design](#requirements-design) 13
>
> [3. Mobile Development (Android/iOS)](#mobile-development-androidios)
> 13
>
> [4. Backend Services (Aggregator, Rule Evaluator, Notification
> Dispatcher)](#backend-services-aggregator-rule-evaluator-notification-dispatcher)
> 13
>
> [5. Data & Analytics](#data-analytics) 13
>
> [6. DevOps & CI/CD (GitHub Actions, ECR, EKS
> manifests)](#devops-cicd-github-actions-ecr-eks-manifests) 13
>
> [7. QA & Testing (unit, integration, device testing,
> accessibility)](#qa-testing-unit-integration-device-testing-accessibility)
> 13
>
> [8. Pilot Testing & Feedback loop](#pilot-testing-feedback-loop) 13
>
> [9. Final Documentation & Handover](#final-documentation-handover) 13
>
> [10. Requirements Traceability
> Matrix](#requirements-traceability-matrix) 13
>
> [11. Acceptance Criteria and Success
> Metrics](#acceptance-criteria-and-success-metrics) 14
>
> [12. Requirements measurement & change
> control](#requirements-measurement-change-control) 14
>
> [13. Risks, constraints, and
> mitigations](#risks-constraints-and-mitigations) 14

##  

## 1. Introduction

### 1.1 Purpose

This document specifies the functional and non-functional requirements
for LockdIn, a mobile-first digital well-being application whose primary
objective is to reduce unhealthy screen time by enforcing app lockdowns
and supporting behavioral insights and accountability. The SRS documents
the complete set of requirements needed to design, develop, test,
deploy, and validate the system.

### 1.2 Intended Audience

- Project sponsor and stakeholders

- Development team (frontend, backend, DevOps)

- QA/Testers

- UX/UI designers

- System architects and security/privacy reviewers

- Project manager and scrum master

- Graders / course instructors

### 1.3 Scope

LockdIn is a mobile application (Android initial priority, IOS limited
by platform constraints) and associated backend services. It provides
usage-tracking, rule-based lockdown/enforcement (hard on Android, soft
on IOS), analytics dashboards, notifications with tone profiles, and
optional accountability reporting to contacts. The system includes
backend microservices, a managed Postgres DB, CI/CD pipelines, and
mobile clients. Core scope includes features required for an initial
working prototype and pilot testing.

### 1.4 Definitions, Acronyms, Abbreviations

- **HLR** (High-Level Requirement)

- **FR** (Functional Requirement)

- **NFR** (Non-Functional Requirement)

- **API** (Application Programming Interface)

- **gRPC** (gRPC remote procedure call framework)

- **EKS** (AWS Elastic Kubernetes Service)

- **RDS** (AWS Relational Database Service (Postgers)

- **WCAG** (Web Content Accessibility Guidelines)

- **GDPR** (General Data Protection Regulation)

##  

## 2. Overall Description

### 2.1 Product Perspective

LockdIn is a client-server system: native mobile clients (Android, IOS)
connect to a cloud backend (microservices deployed in Kubernetes on
AWS). The backend ingests usage events, maintains aggregates, evaluates
rules, and issues actions (lock/notify). The architecture follows the
design in the Architectural & Algorithmic Model: load-balanced ingress,
frontend APIs, backend services (Usage Aggregator, Rule Evaluator,
Notification Dispatcher), managed Postgres DB, CI/CD pipeline, and
least-privilege IAM.

> **Primary interactions:**

- Mobile app -\> HTTPS -\> API Gateway/Ingress -\> Frontend services

- Frontend -\> gRPC -\> Backend services -\> Postgres

- Notification Dispatcher -\> Push, SMS, Email providers

### 2.2 System Interfaces

- Mobile SDKs / platform APIs: Android UsageStats / Device Admin or
  LockTask APIs, IOS Screen Time / DeviceActivity APIs.

- External notification/email/SMS providers (e.g., Firebase Cloud
  Messaging, AWS SNS/SES, Twilio optional).

- CI/CD: GitHub Actions, ECR, Kubernetes manifests.

- Database: Postgres (RDS/Aurora). All traffic encrypted in transit;
  data encrypted at rest with KMS.

### 2.3 User Classes and Characteristics

- **Primary Users:** Students and young professionals seeking to reduce
  screen time. Mobile-savvy, privacy-conscious, willing to grant
  permissions.

- **Secondary Users:** Accountability contacts (friends, mentors) who
  receive occasional reports.

- **Administrators / DevOps:** Mange deployment, monitoring, and
  incident response (limited access).

- **QA/Testers:** Responsible for validation, testing across devices.

- Users vary in technical skill; UI must be simple and accessible.

### 2.4 Operating Environment

- **Android:** support Android 10+ (API 29+) as baseline.

- **IOS:** support IOS 15+ (given API constraints).

- **Backend:** AWS (EKS cluster), private ECR, PostgreSQL (RDS/Aurora),
  GitHub Actions for CI/CD.

- **Network:** TLS for all external communications; internal service
  calls secured with mTLS or TLS.

### 2.5 Constraints and Assumptions

- IOS system restrictions: cannot enforce non-bypassable hard lackdowns;
  only soft limits allowed.

- No paid cloud budget in initial phase; use developer-tier cloud and
  managed services sparingly.

- Mobile devices are team-owned for tests. Device diversity is limited.

- Legal/regulatory constraints: privacy (GDPR-style) and
  data-minimization rules apply.

### 2.6 Assumptions and dependencies

- Users grant required permissions (usage access, notifications).

- Third-party push/email services are available and reliable.

- Team has access to Android Studio/Xcode and test devices.

- Backend dependencies (RDS, EKS) are provisionable within the project’s
  resources.

##  

## 3. System Features

### 3.1 FR-1: User Registration and Login

- **ID:** FR-1

- **Priority:** High

- **Description:** Users must be able to create an account and securely
  authenticate. Authentication supports email/password and optionally
  OAuth sign-in (Google). Passwords stored securely (hashed + salt).
  Sessions expire after configurable inactivity. Option for anonymous /
  device-only mode (local-only) must be supported for privacy-conscious
  users (see NFRs)

- **Accepted Criteria:** User can register, verify email (optional),
  login, and logout. Login failures are handled with user-friendly
  messages. Account recovery via email is available.

### 3.2 FR-2: App Usage Monitoring and Event Ingestion

- **ID:** FR-2

- **Priority:** High

- **Description:** Track per-app usage events (appId, timestamp,
  duration) daily and weekly. Mobile client batches events and sends to
  backend via ‘POST /api/v1/usage’ with required fields. Backend
  validates and stores events and updates aggregates.

- **Acceptance Criteria:** Backend accepts usage events, stores them,
  and daily totals per app per user are queryable.

### 3.3 FR-3: Lockdown Mechanism (Android Hard Locks)

- **ID:** FR-3

- **Priority:** High

- **Description:** On Android, the app must enforce non-bypassable
  locking of specified apps when user-defined limits are reached, using
  Device Admin / LockTask or approved platform APIs. On action, the
  backend returns a lock command, and the mobile client invokes the
  platform API to block app usage. Lock/unlock events are logged.

- **Acceptance Criteria:** On reaching limit, targeted apps become
  blocked on test Android devices; unlocking requires configured
  workflow (PIN, wait period, or account-based override as defined).

### 3.4 FR-4: Soft Lock /Reminders (IOS)

- **ID:** FR-4

- **Priority:** Medium

- **Description:** Because IOS does not permit forced app blocking by
  third-party apps, the client must present prominent reminders/overlays
  using Screen Time / DeviceActivity APIs or local notifications.

- **Acceptance Criteria:** On IOS, when limits are reached, user
  receives the configured reminder or overlay with the configured tone
  template.

### 3.5 FR-5: Rule Configuration and Management

- **ID:** FR-5

- **Priority:** High

- **Description:** Users can create, edit, enable/disable rules. Rules
  support: per-app limit (time per day/week), category-based limits,
  schedules (only between X and Y hours), recurrence, and exceptions.
  Rules must be stored, versioned, and applied by Rule Evaluator
  service.

- **Acceptance Criteria:** Users can create a rule (e.g., Instagram -\>
  2 hours/day), backend stores rule, Rule Evaluator enforces.

### 3.6 FR-6: Analytics and Dashboard

- **ID:** FR-6

- **Priority:** Medium

- **Description:** Provide charts and lists for daily/weekly totals, top
  apps, peak hours, trends, and location-based patterns (opt-in). API:
  ‘GET /api/v1/analytics?userId=…’ returns summary JSON. UI drill-downs
  available.

- **Acceptance Criteria:** Dashboard loads within performance targets
  and displays correct aggregated values for sample data. Users can
  filter by date range.

### 3.7 FR-7: Notification and Tone Profiles

- **ID:** FR-7

- **Priority:** High

- **Description:** Notification templates (friendly, motivational,
  humorous/edgy, professional). Users select tone per rule. Dispatcher
  formats messages and sends via push; optionally emails for
  accountability. Throttle/rate-limiting policy for notifications.

- **Acceptance Criteria:** Upon rule trigger, selected tone message is
  delivered via push (and email/SMS for accountability if configured).
  Notification history available in app.

### 3.8 FR-8: Accountability Contacts and Reporting

- **ID:** FR-8

- **Priority:** Medium

- **Description:** Users may opt-in to add accountability contacts. On
  opt-in, the system can send summary/report when limits are exceeded.
  Contacts must explicitly be added by user and consent logged. The
  report includes only minimal agreed-upon data (totals, times).

- **Acceptance Criteria:** When enabled, a contact receives an email/SMS
  with the defined report format and no raw sensitive data.

### 3.9 FR-9: Settings, Export, and Privacy Controls

- **ID:** FR-9

- **Priority:** High

- **Description:** Provide privacy settings (local-only mode, data
  retention period, delete account/data export), onboarding consent
  prompts, and permission explanations. Support GDPR-like rights: data
  export and deletion.

- **Acceptance Criteria:** Users can set retention policy, request data
  export, and delete account with backend confirming deletion.

### 3.10 FR-10: Background Jobs and Scheduled Summaries

- **ID:** FR-10

- **Priority:** Medium

- **Description:** Scheduled tasks compute aggregates, purge or roll-up
  older raw events, compute trends, and generate daily/weekly summaries
  for users. Amin-configurable retention/roll-up schedules.

- **Acceptance Criteria:** Aggregates computed and retained per policy;
  purges older raw data as configured.

##  

## 4. External Interface Requirements

### **4.1 User Interfaces** 

- Native Android and IOS apps. Consistent core flows: Onboarding and
  consent, Dashboard, Rule creation, Settings, Notifications history,
  Account management.

- UI must meet WCAG 2.1 AA-level accessibility for mobile (large touch
  targets, labels for screen readers, color contrast, scalable fonts).

- Optional web-based analytics view (responsive web) accessible via
  authenticated sessions.

### **4.2 APIs** 

- Public-facing endpoints:

  - “POST /api/v1/usage”: usage vent ingestion (JSON).

  - “GET /api/v1/analytics?userId=”: aggregated analytics.

  - “POST /api/v1/checkLimits”: rule check request (synchronous or
    asynchronous).

  - “POST /api/v1/notify”: notifications request (internal).

- Internal services communicate via gRPC with protobuf schemas (fast
  inter-service communication). All endpoints require authentication
  (OAuth tokens or session tokens).

### **4.3 Hardware Interfaces** 

- Uses Android Device Admin / LockTask APIs for locking. Uses IOS
  DeviceActivity / Screen Time APIs for soft limits. Device-specific
  behavior must degrade gracefully.

### **4.4 Communication Interfaces** 

- TLS 1.2+ for all traffic. Use ACM for TLS certs at ALB. FCM for push
  notifications (Android/IOS), AWS SES/SNS or external provider for
  email/SMS. Webhooks for callbacks (if needed).

##  

## 5. Non-functional Requirements

### 5.1 Performance

- **NFR-PERF-1:** interactive UI actions (opening dashboard, switching
  tabs) should be completed within 2 seconds under normal network
  conditions.

- **NFR-PERF-2:** API latency SLO for GET /analytics: p95 ≤ 300ms for
  cached aggregated queries; p95 ≤ 800ms for uncached.

- **NFR-PERF-3:** usage ingestion endpoint must handle bursts of events
  (e.g., 200 events/sec) and scale horizontally.

### 5.2 Reliability & Availability

- **NFR-REL-1:** Backend availability target ≥ 95% during the testing
  period (measured monthly).

- **NFR-REL-2:** Critical data (aggregates) replicated/backed up
  nightly; DB backups must be restorable to within 24 hours.

### 5.3 Security & Privacy

- **NFR-SEC-1:** All sensitive data encrypted at rest (RDS with KMS) and
  in transit (TLS).

- **NFR-SEC-2:** Apply least-privilege IAM roles (pods, CI/CD).

- **NFR-SEC-3:** Container images scanned for vulnerabilities before
  deployment.

- **NFR-PRIV-1:** Privacy-by-design. Only store aggregated usage metrics
  where possible. Raw event retention must be minimal and governed by
  user-configurable retention policies.

- **NFR-PRIV-2:** Provide explicit consent flow during onboarding; log
  consents.

### 5.4 Usability & Accessibility

- **NFR-UX-1:** Onboarding must be completable within ≤ 2 minutes (for
  consenting users).

- **NFR-UX-2:** App satisfies WCAG 2.1 AA for mobile; support
  VoiceOVer/TalkBack.

### 5.5 Portability & Compatibility

- **NFR-PORT-1:** Android support: API 29+/Android 10+.

- **NFR-PORT-2:** IOS support: IOS 15+.

- **NFR-PORT-3:** Backend components cross-platform portable
  (containerized Docker images).

### 5.6 Maintainability & Testability

- **NFR-MNT-1:** Codebase must include unit/integration tests with
  automated execution in CI.

- **NFR-MNT-2:** Major modules must have ≥ 70% code coverage measured by
  unit tests.

### 5.7 Scalability

- **NFR-SCL-1:** System must scale horizontally (EKS autoscaling) to
  handle increased ingest/analytics load. Design for 10x pilot workload
  headroom.

## 6. Data Requirements

### Data elements

- **User:** userId, email (optional), preferences, retentionPolicy,
  consentLogs

- **UsageEvent:** eventide, userId, deviceId, appId, category,
  startTimestamp, durationSeconds, location (optional, opt-in)

- **Rule:** ruleId, userId, targetApps/categories, limitType
  (daily/weekly), limitSeconds, schedule, enabled, createdAt, updatedAt

- **Aggregate:** userId, date, appId, totalSeconds, rollingWeekTotal,
  peakHour

- **NotificationLog:** notificationId, userId, ruleId, type, tone,
  status, timestamp

- **Accountability:** contactId, userId, contactType (email/sms),
  consentTimestamp

### Retention & anonymization:

- Raw UsageEvents retained for default 7 days, then rolled up into
  aggregates. Retention configurable per user (minimum 0, maximum 365
  days) per privacy policies.

## 7. Use Cases

Each use case below includes: actors, preconditions, main flow,
postconditions, and exceptions.

### Use Case UC-01: Onboard & Grant Permissions

- Actors: New user

- Preconditions: App installed.

- Main flow: User opens app → onboarding explains purpose & data uses →
  user grants necessary platform permissions (usage access,
  notifications, device admin if Android) → user completes minimal
  profile → account created or chooses device-only mode.

- Postconditions: User account created or device only; consents logged.

- Exceptions: If user denies permissions, the app offers a limited mode
  and explains limitations.

### Use Case UC-02: Create Lockdown Rule

- Actors: Authenticated user

- Preconditions: User has granted usage access.

- Main flow: User opens Rules → Create rule (select app(s) or category,
  set daily limit e.g., 7200s, set schedule) → Save → Backend persists
  rule → Rule Evaluator scheduled.

- Postconditions: Rule active; Rule Evaluator will evaluate ongoing
  usage.

- Exceptions: Invalid rule parameters cause validation error.

### Use Case UC-03: Usage Event Ingestion

- Actors: Mobile client (automated)

- Preconditions: App running in background; permission granted.

- Main flow: Client collects event → batch sends to POST /api/v1/usage →
  Backend validates → persists events → updates aggregate.

- Postconditions: Aggregates updated; checkLimits may be triggered.

- Exceptions: Network error → events cached and retried.

### Use Case UC-04: Evaluate Limits & Enforce

- Actors: Backend Rule Evaluator, Mobile client

- Preconditions: Aggregates reflect current usage; rules exist.

- Main flow: Rule Evaluator compares usage vs limits → if exceeded
  produce action (lock or notify) → Persist event → send action to
  mobile client → client executes lock or shows reminder.

- Postconditions: App locked on Android or reminder shown on iOS; logs
  stored.

- Exceptions: DB outage → respond with {"action":"error"} and client
  retries later, or local fallback enforcement.

### Use Case UC-05: Send Accountability Report

- Actors: Notification Dispatcher, Accountability contact

- Preconditions: User enabled accountability & added contact.

- Main flow: When rule triggered, prepare minimal report → send via
  email/SMS → log delivery status.

- Postconditions: Contact receives report.

- Exceptions: Delivery failure → retry policy or disable contact after
  repeated bounces.

##  

## 7. Work Breakdown Structure

### **1.** **Project Management & Documentation**

### 2. Requirements & Design

> **2.1.** UI/UX design (wireframes, prototypes)
>
> **2.2.** Architecture and infra planning

### 3. Mobile Development (Android/iOS)

> **3.1.** Android core features (monitoring, locking)
>
> **3.2.** IOS core features (monitoring, soft limits)

### 4. Backend Services (Aggregator, Rule Evaluator, Notification Dispatcher)

> **4.1.** Usage Aggregator service
>
> **4.2.** Rule Evaluator and Lock Dispatcher
>
> **4.3.** Notification Dispatcher
>
> **4.4.** Auth Service and API Gateway

### 5. Data & Analytics

### 6. DevOps & CI/CD (GitHub Actions, ECR, EKS manifests)

### 7. QA & Testing (unit, integration, device testing, accessibility)

### 8. Pilot Testing & Feedback loop

### 9. Final Documentation & Handover

### 10. Requirements Traceability Matrix

<table>
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<thead>
<tr class="header">
<th><blockquote>
<p><strong>HLR</strong></p>
</blockquote></th>
<th><blockquote>
<p><strong>FR(s)</strong> that satisfy it</p>
</blockquote></th>
</tr>
<tr class="odd">
<th><blockquote>
<p>HLR-1 (Usage Monitoring)</p>
</blockquote></th>
<th><blockquote>
<p>FR-2, FR-6</p>
</blockquote></th>
</tr>
<tr class="header">
<th><blockquote>
<p>HLR-2 (Custom Lockdown Rules)</p>
</blockquote></th>
<th><blockquote>
<p>FR-5, FR-3, FR-4</p>
</blockquote></th>
</tr>
<tr class="odd">
<th><blockquote>
<p>HLR-3 (Behavioral Insights)</p>
</blockquote></th>
<th><blockquote>
<p>FR-6, FR-2</p>
</blockquote></th>
</tr>
<tr class="header">
<th><blockquote>
<p>HLR-4 (Notification Tone)</p>
</blockquote></th>
<th><blockquote>
<p>FR-7</p>
</blockquote></th>
</tr>
<tr class="odd">
<th><blockquote>
<p>HLR-5 (Accountability Contacts)</p>
</blockquote></th>
<th><blockquote>
<p>FR-8</p>
</blockquote></th>
</tr>
<tr class="header">
<th><blockquote>
<p>HLR-6 (Quick Onboarding)</p>
</blockquote></th>
<th><blockquote>
<p>FR-1, UC-01</p>
</blockquote></th>
</tr>
<tr class="odd">
<th><blockquote>
<p>HLR-13 (Android Lockdown)</p>
</blockquote></th>
<th><blockquote>
<p>FR-3</p>
</blockquote></th>
</tr>
<tr class="header">
<th><blockquote>
<p>HLR-14 (IOS Soft Limits)</p>
</blockquote></th>
<th><blockquote>
<p>FR-4</p>
</blockquote></th>
</tr>
<tr class="odd">
<th><blockquote>
<p>HLR-15 (Data Minimization &amp; Consent)</p>
</blockquote></th>
<th><blockquote>
<p>FR-9, NFR-PRIV</p>
</blockquote></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

### 11. Acceptance Criteria and Success Metrics

> Acceptance tests for each major deliverable:
>
> • **Prototype Android:** Core monitoring, rule creation, and
> hard-locking on supported Android devices. Passes device tests (≤5%
> crash rate), onboarding ≤2 minutes.
>
> • **Analytics:** “GET /analytics” returns correct aggregated values on
> sample datasets; charts render in UI and load within 2 seconds.
>
> • **Notifications:** Tone templates deliver as configured; 90% success
> on push deliveries in test environment.
>
> • **Accountability:** 50% of pilot users who opt-in actually receive
> reports in pilot (metric tracked).
>
> • **Pilot success metrics (as per Project Charter):** 25% reduction in
> daily screen time after 4 weeks (target), 70% retention in pilot
> users, satisfaction ≥ 4/5.

### 12. Requirements measurement & change control

- Each requirement will be reviewed in sprint planning and linked to
  GitHub issues.

- Requirements changes require change request: description, rationale,
  impact analysis (time, cost, scope), and approval from Project Manager
  & Advisor.

- Requirements will be measured with test cases in the QA suite;
  acceptance criteria must have pass/fail tests.

### 13. Risks, constraints, and mitigations

> Key risks (summary):

- **IOS restrictions:** Cannot hard-lock apps

  - **Mitigation:** focus Android for enforcement; provide rich IOS
    reminders and UX that encourages compliance.

- **Privacy concerns:** Users any mistrust data collection

  - **Mitigation:** privacy-by-design, local-only mode, minimal
    retention, clear consent UI.

- **Time/resource constraints:** 4-month timeline

  - **Mitigation:** prioritize MVP features, defer advanced AI to Phase
    2.

- **Device compatibility:** Fragmentation across Android devices

  - **Mitigation:** test on representative devices, modularize
    platform-specific code

- **Third-party service failures:** Push/email downtime

  - **Mitigation:** retry policies, alternative providers for pilots.

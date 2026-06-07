# LockdIn System Design Report

SED 700 Capstone 1

Professor Miguel Watler

Crissha Salaritan, Jasleen Kaur, Kasra Bina, Ma Toan Bach

November 30, 2025

# Table of Contents

[**Table of Contents 2**](#table-of-contents)

[1. Introduction & Assumptions 3](#introduction-assumptions)

> [Problem and System Goal 3](#problem-and-system-goal)
>
> [Actors and Users 3](#actors-and-users)
>
> [High-Level Requirements 4](#high-level-requirements)

[2. Architecture 6](#architecture)

> [Architectural Style: Client-Server Architecture
> 6](#architectural-style-client-server-architecture)
>
> [System Context: 6](#system-context)
>
> [Component Overview 8](#component-overview)
>
> [How the Components Interact 10](#how-the-components-interact)

[3. High Level Design 14](#high-level-design)

> [Runtime Environment and Assumptions
> 14](#runtime-environment-and-assumptions)
>
> [System Assumptions 14](#system-assumptions)
>
> [Hardware and OS Integration 14](#hardware-and-os-integration)
>
> [Security Model 15](#security-model)
>
> [User Interface 17](#user-interface)
>
> [Internal Interfaces (Microservice APIs and Communication)
> 19](#internal-interfaces-microservice-apis-and-communication)
>
> [Internal Interfaces Communication
> 22](#internal-interfaces-communication)
>
> [External Interfaces and Communication
> 23](#external-interfaces-and-communication)
>
> [Requirements Mapping 26](#requirements-mapping)
>
> [Diagrams 29](#diagrams)

[4. UML Diagrams 32](#uml-diagrams)

[5. Alternate Designs 38](#alternate-designs)

[6. Low Level Design 41](#low-level-design)

> [Module 1: Usage Aggregator Service (Usage Tracking & Analytics
> Engine)
> 41](#module-1-usage-aggregator-service-usage-tracking-analytics-engine)
>
> [Module 2: Rule Evaluator & Lock Enforcer
> 43](#module-2-rule-evaluator-lock-enforcer)
>
> [Module 3: Notification & Accountability Dispatcher
> 46](#module-3-notification-accountability-dispatcher)
>
> [Module 4: Authentication & User Management
> 49](#module-4-authentication-user-management)
>
> [Database Design & Schema Overview
> 52](#database-design-schema-overview)

[7. Conclusion 55](#conclusion)

##  

# 1. Introduction & Assumptions

## Problem and System Goal

The LockdIn mobile application is designed to help users **reduce
unhealthy screen time by enforcing strict, non-bypassable app lockdowns
once time limits are reached** . In essence, LockdIn provides users with
a reliable, non-ignorable way to control their screen time through
automated usage monitoring, customizable limits, and accountability
features. By combining behavioral tracking, engaging notifications (from
friendly nudges to humorous or edgy motivation), and partner
accountability, the system aims to improve user focus, productivity, and
digital well-being.

## Actors and Users

1.  The primary end-users are **students and young professionals** (or
    more generally, individuals) who are motivated to curb their screen
    time habits . These users interact with a mobile app on their
    device.

2.  A secondary actor is the **accountability partner** (friend, parent,
    or mentor) designated by the user. This contact receives
    notifications or summary reports when the user exceeds limits .

3.  On the system side, the **LockdIn backend** (cloud services) acts as
    an automated actor processing data and enforcing rules.

4.  Additionally, **platform providers** (the mobile OS APIs on
    Android/iOS) are external systems that the app leverages for usage
    statistics and lockdown enforcement (e.g. Android’s Device Admin
    API, Apple’s Screen Time API).

5.  For completeness, **administrators/DevOps** personnel exist as
    actors with limited roles (deploying and maintaining the system
    infrastructure) , though no end-user-facing admin interface is in
    scope.

## 

## High-Level Requirements

The main capabilities of LockdIn are derived from the High-Level
Requirements (HLRs) defined in the project documentation. Refer to the
SRS for detailed requirements, but in summary, the system must:

- **Monitor Device Usage:** Track daily and weekly app usage, and
  provide analytics on totals and trends (HLR-1) . Users should see a
  dashboard of screen time and usage breakdowns.

- **Enforce Lockdown Rules:** Let users define customizable screen-time
  limit rules for apps or categories, and **lock those apps** when
  limits are reached (non-bypassable on Android) (HLR-2) . On iOS,
  enforce “soft” limits via reminders due to platform restrictions.

- **Provide Behavioral Insights:** Offer insights into usage patterns –
  e.g. identifying peak usage times, app category breakdowns, or
  location-based triggers for excessive use (HLR-3) .

- **Custom Notifications:** Support multiple notification tone profiles
  (e.g. fun, edgy, professional) that users can select for reminders, to
  improve engagement (HLR-4) .

- **Accountability Features:** Allow users to nominate a trusted contact
  to receive notifications when limits are exceeded, promoting
  accountability (HLR-5) .

- **Fast Onboarding:** Include a quick onboarding flow (target under 2
  minutes) to get first-time users set up with permissions and a default
  rule (HLR-6) .

- **Accessibility & Privacy:** Ensure the app is accessible (conforming
  to WCAG 2.1 AA for usability by people with disabilities) (HLR-7) .
  Provide privacy controls like “local-only” mode and data export/delete
  options (from additional requirements) .

- **Behavior Change Efficacy:** The product should demonstrably help
  reduce users’ screen time (target ≥25% reduction in average daily
  screen time after 4 weeks of use – HLR-8) .

- **User Retention:** The solution should be engaging and effective
  enough that at least 70% of pilot users continue using it actively
  (HLR-9) .

**Key Assumptions:**

- Development is initially **focused on Android**, since Android’s OS
  permissions allow deeper usage monitoring and true app blocking.

- It is assumed that on iOS, strict lockdown is not possible without
  jailbreaking, so the app will use Apple’s approved APIs to impose soft
  limits and reminders only .

- Users will grant the necessary permissions (usage stats access,
  notification access, device admin on Android, etc.) during onboarding
  .

- Users consent to share basic usage data with the system and with their
  chosen accountability partner – privacy options will be provided, but
  core functionality relies on data collection.

- All required development tools, SDKs, and test devices are available
  to the team, and that the backend infrastructure can be deployed in a
  cloud environment (e.g. AWS) within project resources .

##  

# 2. Architecture

## Architectural Style: Client-Server Architecture

A native mobile client (the LockdIn app on Android/iOS) communicates
over the internet with a cloud-based backend.

The backend is organized as a set of **microservices** deployed on a
scalable cloud platform (Kubernetes on AWS) .

Communication between the mobile app and the backend uses RESTful
**HTTPS** APIs for simplicity (JSON over TLS).

Within the backend, services communicate with each other via
high-performance **gRPC** calls using protocol buffers .

The architecture also includes **external integrations** where the
backend uses a managed **PostgreSQL database** for persistence , and
leverages external messaging services (like Firebase Cloud Messaging,
email/SMS APIs) for pushing notifications to devices or contacts.

This microservice approach (as opposed to a monolithic server) was
chosen for scalability and clear separation of concerns: different
services handle usage data, rule evaluation, notifications, etc., and
can be scaled or modified independently.

## System Context: 

At a high level, the LockdIn system interacts with several external
entities: the end user (via the mobile app UI), the accountability
contact (who receives emails/SMS reports), the mobile OS platforms
(Android/iOS APIs that enable usage tracking and app blocking), and
external notification services (for delivering push notifications or
emails). **Figure 1** illustrates the system context, showing LockdIn
(encompassing the app and backend) at the center and its key external
actors and systems around it:

<img src="media/image2.png"
style="width:3.94271in;height:3.51379in" />

*Figure 1: System context diagram of LockdIn, showing the mobile app and
cloud system in the center, the end user and accountability contact as
external actors, and the platform/notification services it interacts
with.*

In the context diagram, the **End User** interacts with the **LockdIn
System** through the mobile app’s UI (e.g. setting rules, viewing
stats).

The **Accountability Contact** is external but receives output from the
system (notifications/reports when the user exceeds limits).

The LockdIn system also interfaces with **mobile OS APIs** (to gather
usage data and enforce locks via Android Device Administration or iOS
Screen Time frameworks) and with **notification services** (e.g. push
notification infrastructure, email/SMS gateways) to deliver messages out
to users and contacts.

## Component Overview

Internally, the LockdIn backend is composed of several cooperating
microservice components, each with a distinct responsibility. **Figure
2** provides a component and deployment view of the system’s core
elements and their interactions:

<img src="media/image3.png"
style="width:5.7797in;height:4.63073in" />

*Figure 2: High-level component architecture. The LockdIn Mobile App
communicates via HTTPS APIs to cloud services (Auth, Usage Aggregator).
Internal backend services (Usage Aggregator, Rule Evaluator,
Notification Dispatcher) communicate via gRPC and share a Postgres
database. External services (FCM/APNs, email/SMS gateways) are used by
the Notification Dispatcher to deliver messages to devices or contacts.*

As shown in Fig. 2, the **LockdIn Mobile App** (Android or iOS) is the
client component that handles the user interface and local monitoring.
It communicates with the cloud through a **REST API** (HTTPS). Key
backend components include:

- **Auth Service:** Manages user accounts, authentication and
  authorization (fulfilling FR-1). It allows users to register, log in
  (including OAuth options), and manages secure session tokens. It
  interacts with the database to store user credentials (hashed
  passwords) and profiles .

- **Usage Aggregator Service:** Ingests app usage events from the mobile
  app and updates usage statistics and analytics (fulfilling HLR-1 and
  parts of HLR-3). When the app sends periodic usage data (e.g.
  “Facebook used 10 minutes”), this service validates and records the
  event in the **PostgreSQL database**, updating aggregated totals
  (daily and weekly per app/category) . It also provides an API endpoint
  to fetch analytics (e.g. GET /api/v1/analytics) returning summarized
  usage stats for the dashboard .

- **Rule Evaluator Service:** Applies the user-defined rules to the
  aggregated usage and determines if any limit has been exceeded
  (fulfilling HLR-2). It fetches the relevant rules from the database
  and compares current usage against the limits . If a limit is reached,
  the Rule Evaluator formulates an **action** – e.g., a command to lock
  a specific app (on Android) or a notification that time is up (on iOS)
  . This service encapsulates the core logic for enforcing screen-time
  rules.

- **Notification Dispatcher Service:** Handles all user and external
  notifications, including on-device alerts and accountability messages
  (fulfilling HLR-4 and HLR-5). When triggered (either by the Rule
  Evaluator for an immediate limit breach, or by scheduled summary
  jobs), it composes the notification content based on the user’s chosen
  tone profile and the context . It then delivers the notification: for
  the user, typically via a push notification to the mobile app; for an
  accountability contact, via email or SMS. This service connects to
  external providers (e.g. Firebase Cloud Messaging for push, or an
  email/SMS API) to send out the messages . It also logs notification
  deliveries in the database for audit/history.

### How the Components Interact

All these backend services share a common **database (PostgreSQL)** for
persistence of user data, rules, and usage records . They communicate
over a private network (within a Kubernetes cluster). An API Gateway or
NGINX ingress routes external API calls from the app to the appropriate
internal service – for example, usage events are routed to the Usage
service, login requests to Auth. Internal calls (Usage service
triggering the Rule Evaluator, Rule Evaluator calling the Notification
service) use gRPC for efficiency . The mobile app itself also directly
interfaces with OS-level services: on Android it uses the **Usage
Stats** and **Device Admin API** to monitor apps and enforce locks on
the device , while on iOS it uses Apple’s **Screen Time/DeviceActivity
APIs** to monitor usage and display system-managed reminders . These
platform interactions are encapsulated in the mobile client – the
backend simply informs the app *what* action to take (lock or warn), and
the app carries it out using the OS capabilities.

**Non-Functional Considerations**

The architecture is designed for **performance** and **scalability**.
The use of local processing on device (batching usage events) and
lightweight JSON APIs ensures that normal usage reporting has minimal
latency and battery impact. The backend microservices can be scaled
horizontally (e.g. multiple instances of the Usage service behind a load
balancer) to handle increasing numbers of users or events. Because
certain operations (like evaluating rules or sending notifications) are
triggered by events, the system can naturally scale by processing these
in parallel on separate service instances. For **reliability**, data is
stored in a robust ACID-compliant DB (PostgreSQL on AWS RDS) with
backups, and the services run in a clustered environment (able to
recover from node failures). The design includes **retry mechanisms**
and graceful fallbacks – e.g. if the network is down, the mobile app
queues usage events for later ; if the database is unreachable
momentarily, the Rule Evaluator can respond with an “error, try later”
action so the client can enforce a local fallback if possible .

**Security & Privacy**

All communication is encrypted (HTTPS for app-to-backend, and internal
gRPC channels secured via mTLS) . User data in the database is encrypted
at rest via cloud KMS . The system follows a “privacy by design”
approach: it collects only the data needed to implement the features
(mainly app IDs, usage durations, timestamps) and nothing overly
personal . Users can opt for a local-only mode (HLR-9 related feature)
in which raw usage logs are kept only on device and only aggregated
summaries are sent to the backend . All data retention is configurable
and old raw data gets purged or anonymized via background jobs (per data
retention policies) . The app explicitly explains what permissions are
needed and why, during onboarding, to ensure transparency .

**Traceability Matrix**

The table below maps the major High-Level Requirements to the system
components that realize them:

| **HLR (Requirement)**                           | **Relevant Components**                                                                                                                                                              |
|-------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| HLR-1. Monitor daily/weekly usage & show trends | **Mobile App** (collects usage data, displays dashboard), **Usage Aggregator** (tracks events, computes totals), **Analytics DB** (stores usage)                                     |
| HLR-2. Customizable lockdown rules              | **Rule Evaluator** (stores & evaluates rules), **Mobile App** (enforces lock via OS, UI for rule setup)                                                                              |
| HLR-3. Behavioral insights (patterns)           | **Usage Aggregator** (computes trends like peak hours, location patterns), **Mobile App** (UI to present insights)                                                                   |
| HLR-4. Multiple notification tone profiles      | **Notification Dispatcher** (formats message according to tone), **Mobile App** (user selects profile in settings)                                                                   |
| HLR-5. Accountability notifications             | **Notification Dispatcher** (triggers email/SMS to contact), **Backend DB** (stores contact info), **External Email/SMS service**                                                    |
| HLR-6. Quick onboarding ≤2 minutes              | **Mobile App** (streamlined onboarding flow UI), **Auth Service** (fast account setup), **OS integration** (quick permission prompts)                                                |
| HLR-7. Accessibility (WCAG 2.1 AA)              | **Mobile App UI** (high-contrast theme, larger fonts, content descriptions), **Notification content** (accessible wording)                                                           |
| HLR-8. Reduce screen time ≥25%                  | **Rule Evaluator + Mobile App** (hard lockdowns directly reduce usage), **Notification/Insights** (behavior change nudges). *All core features together* contribute to this outcome. |
| HLR-9. ≥70% users remain active                 | **Engaging UX** (Mobile App’s user-friendly design, HLR-7), **Motivational notifications** (HLR-4) – overall system quality and usefulness drive retention.                          |

*(Table notes: This traceability focuses on primary feature components.
Many requirements involve multiple parts of the system in tandem. For
example, HLR-2 involves the backend Rule service and the on-device
enforcement working together. HLR-8 and HLR-9 are business-level goals
achieved by the collective effect of the components listed.)*

##  

# 3. High Level Design

## Runtime Environment and Assumptions

LockdIn is delivered as native mobile apps on **Android** and **iOS**
communicating with a cloud backend. The backend runs as a set of
containerized microservices on a **Kubernetes** cluster (deployed on
AWS) . A **PostgreSQL** database is used for persistent storage (e.g.
usage logs, rules, user info) . The system integrates with external
messaging services: **Firebase Cloud Messaging (FCM)** for Android push
notifications, **Apple Push Notification service (APNs)** for iOS, and
third-party email/SMS APIs (e.g. **AWS SES** for email, **Twilio** for
SMS) to notify accountability partners .

### System Assumptions

We assume users grant all required OS permissions during onboarding
(Android Usage Stats and Device Admin, iOS Screen Time and notification
access) . The initial deployment is a small pilot, so the system is
scaled for a modest number of users, but the cloud architecture can
scale out as needed. Reasonable network latency is assumed for
device-backend communication; the app batches data to tolerate brief
offline periods. Android is the primary platform at first (due to its
deeper monitoring and true app blocking capabilities), while on iOS the
app uses “soft” enforcement given platform limitations . We assume the
backend cluster is reachable with minimal downtime, and that the cloud
environment (AWS) and development tools are available to the team .

## Hardware and OS Integration

LockdIn leverages native OS capabilities for usage tracking and app
blocking. On **Android**, the app uses the **UsageStats API** to
continuously monitor foreground app usage and durations. To enforce
locks, LockdIn enrolls as a **Device Administrator** app, allowing it to
block launches of target apps when limits are exceeded . This means that
once an Android user hits a limit, LockdIn can immediately display a
full-screen “app locked” overlay or otherwise prevent the restricted app
from opening . On **iOS**, third-party apps cannot truly lock other apps
(no equivalent device-admin capability), so LockdIn integrates with
Apple’s Screen Time or Device Activity APIs to read usage statistics and
schedule reminders. When an iOS limit is reached, the app triggers a
**Screen Time reminder notification** – a pop-up alert informing the
user they’ve hit their limit . This “soft” limit relies on the user’s
compliance (due to iOS sandbox restrictions) and cannot force-close the
app, but it still serves as a strong deterrent.

To minimize battery and performance impact on devices, the design
offloads heavy computation to the backend. The mobile app performs only
lightweight tasks (usage logging, UI updates) and batches its data
transmissions. For example, usage events are aggregated on-device and
sent to the server periodically (every few minutes) rather than in real
time, reducing network chatter and conserving battery . The backend
performs resource-intensive work like computing analytics (trends,
insights) and evaluating complex rule logic, taking advantage of cloud
processing power instead of draining the phone’s CPU . This division
also improves enforcement security: rules are checked on a server the
user cannot tamper with easily . Overall, the app respects mobile
constraints by doing just the necessary device-side polling (which is
scheduled in the background as permitted by the OS) and relying on push
notifications from the server to react in real time, rather than keeping
long-running background services active.

## Security Model

Security and privacy are core to LockdIn’s design. All client-server
communication uses **HTTPS** with TLS encryption . Within the backend,
microservice-to-microservice calls use authenticated channels (e.g. gRPC
with mutual TLS) so that even internal traffic is encrypted . The
database encrypts data at rest (using cloud Key Management Service for
keys) . User authentication is handled via JWT tokens: when a user logs
in or registers, the Auth service issues a signed JWT that the client
presents on subsequent requests. Tokens are short-lived and securely
verified on each request (either by a centralized Auth service or via
shared public keys) to prevent spoofing. Passwords (for users who create
accounts) are never stored in plaintext – only securely hashed values
(e.g. bcrypt) are kept in the database . For additional safety, the Auth
module applies measures like rate limiting or exponential backoff on
login attempts to mitigate brute force attacks .

The system follows a “privacy by design” approach , collecting only the
minimum data needed to function – primarily app IDs, usage durations,
timestamps, and basic account info. Personal Identifiable Information
(PII) is kept to a minimum (the system does not collect sensitive
content or detailed user data beyond what’s required for the features).
Users can even opt for an **anonymous (device-only) mode** with no email
or name provided; in this mode, data is stored only locally on the
device or in an anonymized way on the server . Anonymized or local-only
users still get full functionality except cloud backup of data. All data
retention is governed by user control and regulations – users can
request deletion of their data, upon which the backend will erase their
usage records, rules, and contact info (all user-linked records
cascade-delete) . This fulfills GDPR-style requirements for the “right
to be forgotten.” Routine purging is in place for stale data: raw usage
logs older than a retention period are aggregated or anonymized and then
deleted to protect privacy .

**Threat Model**

The system assumes the mobile clients are honest and not compromised; a
determined user with a rooted/jailbroken device might bypass controls,
but such scenarios are out of scope beyond deterrence measures. All API
calls include the user’s token, which is validated to ensure no
unauthorized access – e.g. one user cannot retrieve another’s data. We
mitigate token spoofing by using signed JWTs (non-forgeable without the
server’s secret) and by transmitting them only over TLS. The backend and
database are deployed in a secure VPC with firewall rules; each
microservice and database account uses least-privilege access (only the
permissions it needs) . Data shared with accountability partners is
limited to summary notifications (e.g. a simple “limit exceeded” alert)
to reduce privacy impact if those messages were exposed . In summary,
the design uses standard security best practices (encryption in transit
and at rest, hashed credentials, minimal data storage, and rigorous
auth) to protect user data and ensure only authorized actions occur.

## User Interface

The LockdIn UI is **mobile-first**, designed for clarity and engagement
on small screens. Upon first launch, users go through an **onboarding
wizard** that introduces the app’s purpose and requests the necessary
permissions . The onboarding flow is streamlined (targeting under 2
minutes to complete, per HLR-6) – it guides the user to enable usage
access and admin privileges on Android, or Screen Time and notification
permissions on iOS, with friendly explanations of why each is needed.
Account creation is optional; the user may sign up with email/password
or continue in device-only mode for privacy . Either way, the final
onboarding step suggests a default rule (e.g. a daily total screen time
cap) to help new users get started quickly .

Once onboarded, the user lands on a **Dashboard** screen that summarizes
their device usage. This dashboard shows daily total screen time, a
breakdown by app or category, and weekly trends (e.g. graphs of usage
over days) – fulfilling the analytics insights requirement (HLR-1 and
HLR-3) . The UI employs charts and infographics to make these patterns
easily understandable. A menu or tab interface lets the user navigate
between main sections: **Usage Stats**, **Rules**, and
**Settings/Account**.

In the **Rules** section, users can create and manage their screen-time
limit rules. The rule creation UI allows selecting one or more target
apps (from a list of installed apps, possibly grouped by category),
setting a time limit (e.g. “2 hours per day”), and optionally defining a
schedule or time window for the rule (for example, only enforce on
weekdays or only during 9am-5pm) . The user can also choose a
notification **tone profile** for each rule – e.g. “Friendly”,
“Humorous”, or “Strict” – which determines the style of messaging the
app will use when reminding or warning them (this addresses HLR-4 on
customizable tone) . After configuring, the user saves the rule, which
is then synced to the backend . All rules are listed in the Rules
screen, where they can be edited or deleted. Each rule item shows its
status (active/inactive), the limit and schedule, and maybe a progress
bar or counter showing current usage vs the limit for the day.

The **Accountability Settings** (likely under Settings or a dedicated
tab) let the user manage their accountability partner. Here they can
nominate a trusted contact by providing an email or phone number. The UI
explains what the contact will receive (e.g. a daily or immediate
notification when limits are exceeded) to ensure transparency. The user
can enable/disable accountability at any time or change the contact. The
**Settings** area also covers other preferences such as the default
notification tone profile, data privacy options (like toggling the
local-only mode), and accessibility options.

The app’s **UX** is designed with accessibility and simplicity in mind
(HLR-7). It uses high-contrast color schemes and readable font sizes,
and supports screen readers by labeling all buttons and graphs with
descriptive text. For example, the “lock” screen and notifications
include clear text and consider color-blind friendly indicators. The
content of motivational messages adapts to the chosen tone but remains
comprehensible and avoids any offensive language.

**Lock Screen UI (Android vs iOS):** There are platform-specific
differences in how a “locked” app is presented. On **Android**, if a
limit is exceeded and a rule triggers a lockdown, the LockdIn app
(running in the background) will use its Device Admin authority to
immediately block the target app. In practice, if the user tries to open
that app, they will see a LockdIn overlay screen informing them that the
app is locked, possibly with the reason (“You’ve reached 2 hours on
Instagram today”) and no option to bypass . This screen is designed to
be attention-grabbing but not overly hostile – depending on the tone
setting, it might even include a humorous quip or an encouragement to
take a break. On **iOS**, a true lock screen takeover is not possible;
instead, when a limit is hit, LockdIn schedules a local notification or
a Screen Time alert that pops up on the device. The iOS notification
might say “Time’s up for Instagram – limit reached.” The user can
dismiss it, but the app relies on this nudge combined with Apple’s
built-in Screen Time restrictions (if any) to dissuade further use . In
both cases, the UI ensures the user is aware that the limit condition
has been triggered. If the user launches the LockdIn app after that, the
dashboard may highlight that an app is currently locked and when it will
be available again (e.g. “Instagram locked until tomorrow”).

## Internal Interfaces (Microservice APIs and Communication)

Internally, the backend is composed of several microservices, each
exposing a focused API (REST for external calls, gRPC for internal
calls). Key services and their interfaces include:

- **Authentication Service:** Manages user accounts and sessions. It
  provides endpoints like POST /auth/register (create new account with
  email & password) and POST /auth/login (verify credentials and issue a
  JWT). On successful registration/login, it returns an auth token used
  by the mobile app for subsequent requests. The Auth service also
  offers a token validation function (e.g. an internal gRPC method or
  middleware) that other services use to authenticate requests. If users
  choose device-only mode, the Auth service generates an anonymous token
  or device ID with limited scope. All password handling and email
  verification is done here (e.g., sending a verification email via SES
  if required). JWTs are short-lived and need periodic refresh; a GET
  /auth/refresh might be provided to get a new token using a refresh
  token (or this can be built into the login flow). The service stores
  user profiles and credential hashes in the database.

- **Usage Aggregator Service:** This service is responsible for
  receiving raw usage events from the clients and compiling them into
  meaningful stats. Externally, the mobile app calls POST /usage (or
  /api/v1/usage) to send batches of usage records . Each record includes
  user ID (or is authed by token), app identifier, timestamp, and
  duration of usage. The Usage service validates and writes these events
  to the database, and updates running aggregates (like total usage per
  app per day) . It may also provide a GET /analytics endpoint for the
  app to fetch summarized statistics – for instance, the dashboard might
  call GET /analytics?range=week to retrieve a user’s daily totals,
  most-used apps, and trends . Internally, after storing new usage data,
  this service notifies the Rule Evaluator to check if any limits are
  now exceeded. This could be done synchronously via a gRPC call like
  CheckUsageUpdate(userId, appId) or by publishing an event (e.g. on a
  message queue) containing the updated usage totals . In some cases,
  the mobile app might also proactively call a POST /checkLimits
  endpoint on the Rule service after uploading usage, but the typical
  flow is for the backend to handle it. The Usage service focuses on
  data collection and simple aggregations, leaving decision logic to the
  Rule service.

- **Rule Evaluator & Lock Enforcement Service:** This core service
  maintains all user-defined rules and evaluates whether any rule
  criteria are met. It exposes endpoints for rule management – e.g. POST
  /rules to create a new rule, GET /rules to list a user’s rules, and
  PUT /rules/{id} or DELETE /rules/{id} to update or remove rules. When
  the mobile app saves a new rule, it sends it to this service (through
  the backend API gateway) . The Rule service stores the rule definition
  in the database (associating it with the user) and likely caches
  active rules in memory for quick access. The **evaluation interface**
  can be triggered in two ways: (1) internal gRPC call from Usage
  service – e.g. CheckLimits(userId) – whenever new usage arrives,
  or (2) a scheduled job (for rules that might need time-based checks).
  On invocation, the Rule Evaluator retrieves the latest usage totals
  (for the day, week, etc. depending on rule type) from the database or
  from the passed data, and compares against each active rule for that
  user . If no limits are exceeded, it returns an “OK” status (or no
  action) . If a rule threshold is reached or crossed, the Rule service
  produces a **Limit Exceeded event**. This includes details like which
  rule was triggered, which app or category it concerns, what the limit
  was, and possibly a message to show the user (“Limit reached for
  Instagram”) . Instead of contacting the device directly, the Rule
  Evaluator hands off the event to the Notification service for further
  handling . This internal call might be something like
  NotifyService.handleLimitEvent(userId, ruleId, appId, message,
  notifyContact) . The Rule Evaluator then records that the rule has
  been triggered (to avoid duplicate notifications) and could log the
  event to a “lock events” table for audit. It also handles edge cases
  like multiple rapid triggers (ensuring one limit event per rule per
  interval). For Android-specific rules, this service might also prepare
  a payload instructing the device to lock a certain app (though the
  actual locking action is executed on the device via Device Admin). In
  summary, this service encapsulates the business logic of **when to
  lock** and leaves **how to lock** to the device and Notification
  service.

- **Notification & Accountability Dispatcher:** This service is the
  central hub for all outbound notifications – both to the end-user’s
  device and to the user’s designated contact. It doesn’t have many
  external endpoints for the mobile app; instead, it mostly listens for
  internal events. One possible external endpoint is a GET
  /notifications or subscription endpoint for the app to fetch any
  pending notifications (in case push fails and it needs to poll), but
  primarily it works by pushing messages. Internally, it exposes methods
  like HandleLimitExceeded(event) which the Rule Evaluator calls when a
  user exceeds a limit. It may also have a scheduled internal trigger
  for daily/weekly summary notifications (e.g., every day at 9pm, send a
  summary of today’s usage to the user or their partner, fulfilling a
  non-critical requirement for reports). When the dispatcher receives a
  **limit event**, it looks up the user’s preferences (their chosen
  notification tone, and whether an accountability contact is enabled) .
  It then formats the notification message accordingly. For example, if
  the tone is “edgy,” the message to the user might be “That’s enough
  Instagram for today – get back to reality 😜,” whereas a
  “professional” tone would be more formal . The Notification service
  then delivers: it uses the appropriate **push channel** to send a
  real-time alert to the user’s device, and if an accountability partner
  is set, it sends an email or SMS to that contact .

  - **Push to Mobile App:** The service sends a high-priority push
    message via FCM (for Android) or APNs (for iOS), containing the
    instruction that a limit was exceeded and which app to lock. The
    mobile app, upon receiving this push, will display a local
    notification or directly invoke the OS-specific lock mechanism as
    described earlier . The push payload is kept minimal (perhaps just a
    code or flag and message) for security. This mechanism ensures the
    user gets notified immediately even if the app is in the background.

  - **Contact Notifications:** If the user has an accountability
    contact, the Notification service composes a brief email or SMS for
    them. It might use an external email API (such as AWS SES) to send
    an email like “Alert: John has exceeded their Instagram daily limit
    of 2 hours today,” or a similar SMS via Twilio . These messages
    respect privacy – they do not include sensitive details, only the
    fact that a limit was exceeded and perhaps the app or category
    involved . The service then handles any delivery feedback (for
    example, if an email bounces or an SMS fails, it can log this and
    maybe notify the user to update the contact info).

In addition to handling immediate events, the Notification Dispatcher
might also be responsible for periodic summary notifications (if
required by requirements). For instance, it could send the
accountability partner a weekly summary email with the user’s total
screen time and whether they stayed under limits, etc. This would be
generated from aggregated data in the database, triggered by a scheduled
job or cron within the service.

## Internal Interfaces Communication

The microservices communicate primarily through synchronous gRPC calls
for real-time events (e.g. Usage -\> Rule, Rule -\> Notification) and
share data via the database. For example, when POST /usage is received,
the Usage service writes to DB and then invokes the Rule service’s gRPC
method CheckLimits with the user’s updated stats . When a limit is
exceeded, the Rule service calls the Notification service’s method
SendLockNotification (for instance) and passes the details . This
decoupling means each service focuses on its role while cooperatively
implementing the overall logic.

## External Interfaces and Communication

**Mobile REST API:** The mobile clients communicate with the backend
over a RESTful API secured with HTTPS . Key external endpoints include:

- POST /api/v1/auth/register and POST /api/v1/auth/login for account
  management (as described above).

- POST /api/v1/usage for sending usage data batches from the app to the
  server . The request body contains one or more usage events (app IDs
  and durations), and the server responds with a simple acknowledgment
  (and possibly an immediate limit check result or new instructions,
  though in our design the limit check happens server-side after
  ingestion).

- GET /api/v1/analytics (and related endpoints) for retrieving
  aggregated usage stats. The app uses this to populate the dashboard,
  e.g. GET /api/v1/analytics?period=week returns a JSON with daily
  totals, top apps, and any insights .

- POST /api/v1/rules to create a new rule , and GET /api/v1/rules to
  fetch the user’s current rules. Edits and deletes might be PUT or
  DELETE /api/v1/rules/{ruleId}. These endpoints allow the app to manage
  the user’s lockdown settings.

- POST /api/v1/contact (or part of a profile endpoint) to set or update
  the accountability partner’s contact info. (For example, the app
  provides an email or phone number and the server stores it and perhaps
  sends a confirmation invite.)

- GET /api/v1/config or similar, to fetch app configuration flags or
  updates (this could include whether the user is in device-only mode,
  feature toggles, etc., though not strictly required).

All these REST endpoints expect a valid Authorization header with the
user’s JWT; the backend will respond with 401 Unauthorized if the token
is missing or invalid. Data formats are JSON. The API is designed to be
used by the mobile apps only (there’s no public/open API for third-party
clients in this pilot). Given the real-time nature of limit enforcement,
the app rarely needs to poll for anything – usage data is pushed up by
the client, and notifications are pushed down by the server. The GET
/analytics calls are made when the user actively opens their dashboard.

**Push Notification Channels**

LockdIn uses push notifications for real-time communication to the app.
On Android, the app registers with **Firebase Cloud Messaging (FCM)** to
receive messages from the backend. On iOS, it registers with **APNs**.
The Notification service in the backend, when triggering a device alert,
will call the respective push service’s API (for example, the FCM send
API with the device’s token, or Apple’s HTTP/2 push endpoint with the
iOS device token). These messages carry a small payload (including
perhaps a type like “LOCK_COMMAND” and the target app identifier). Both
FCM and APNs require credentials (server keys, certificates) which the
LockdIn backend securely stores and uses. The external push services
ensure delivery to the device even if the app is not active.

**Email and SMS Gateways**

For accountability features, the system integrates with external
communication APIs. **Email** notifications are sent via a service like
Amazon **SES** or SendGrid. LockdIn’s backend uses the SES API to
compose and send emails to the designated contact’s address. Similarly,
for **SMS**, the system might use

**Twilio’s REST API** (or an AWS SNS SMS service)

To send text messages to a phone number. Both types of messages are
triggered by internal events (usually the Notification service deciding
to alert a contact). The content of these messages is kept simple to
avoid any privacy breach – e.g. “LockdIn Alert: \[User’s first name\]
exceeded their \[App name\] time limit today.” . The backend handles any
API responses from these services (such as delivery success or error).
If an error occurs (invalid address, etc.), it logs it and could notify
the user in-app that their contact was unreachable . These external
interfaces require network connectivity and correct configuration of API
keys, but they allow LockdIn to extend its reach beyond the app itself,
creating a social accountability loop via standard communication
channels.

**OS-Level Integrations**

Although not “interfaces” in the web API sense, it’s worth noting that
the mobile apps also interface with OS-level frameworks. The Android app
interacts with the **Android OS Device Administration** API to enforce
locks, and uses the Usage Stats permission to query system usage stats.
The iOS app uses Apple’s **Screen Time APIs/Device Activity** framework
for reading usage data and scheduling notifications. These integrations
are constrained by what the OS providers allow third-party apps to do
(for example, iOS Screen Time data might be read via an API if the user
grants permission, but enforcement is limited to notifications as
discussed). In design documentation, we treat these OS services as
external systems that our app calls into or uses, much like an API. For
instance, the app might call an Android Manager method to disable an app
or use a Screen Time threshold on iOS to generate the reminder.

## Requirements Mapping

The high-level design addresses the major requirements (HLRs from the
SRS) and non-functional goals as follows:

- **Device Usage Monitoring (HLR-1):** The Usage Aggregator service and
  mobile app implement this. The app collects per-app usage and uploads
  it , the backend compiles daily/weekly totals, and the dashboard UI
  presents charts and trends . This satisfies the need for tracking
  screen time and showing usage breakdowns (e.g. by day and by app).

- **Custom Lockdown Rules (HLR-2):** The Rule Evaluator and on-device
  enforcement fulfill the core lockdown functionality . Users can create
  flexible rules (by app or category, with time limits and schedules) in
  the app UI . The backend stores these rules and checks usage against
  them in real time. When limits hit, the system enforces a lock – on
  Android, via a non-bypassable Device Admin action; on iOS, via a
  Screen Time notification (soft limit) . This design meets the
  requirement of strict enforcement on Android and best-effort reminders
  on iOS, preventing further use once limits are exceeded.

- **Behavioral Insights (HLR-3):** The design includes analytics
  generation in the Usage service. It can compute patterns like peak
  usage times or detect if the user consistently uses a certain app at
  night. These insights are delivered through the app’s Analytics
  dashboard . For example, the system might highlight “Your heaviest
  usage is around 10 PM” or show category-wise breakdowns. The data
  model and aggregator support these computations by storing timestamps
  and categories of apps. Thus, the requirement for weekly trends and
  usage patterns is supported.

- **Notification Tone Profiles (HLR-4):** The Notification Dispatcher
  uses the user’s selected tone profile to tailor messages . The UI
  allows the user to choose a tone (e.g. fun or professional), and that
  preference is stored per user. When sending reminders or warnings, the
  system picks from a set of pre-defined messages/templates
  corresponding to that tone. For instance, a “fun” tone message might
  use emojis and a casual phrase, whereas a “strict” tone message is
  more stern. By incorporating this into the notification content, the
  design achieves a personalized, engaging experience as required .

- **Accountability Alerts (HLR-5):** The inclusion of an accountability
  partner feature is realized through the Notification service’s
  emails/SMS to the contact . The user can add a contact in the app; the
  backend stores it and whenever a limit is exceeded (or in daily
  summary), an alert is sent to that contact . This satisfies the
  requirement of involving a third party for accountability. The system
  ensures the content is privacy-conscious (no detailed data, just that
  a limit event occurred) and provides this promptly to help motivate
  the user to stick to their goals.

- **Fast Onboarding (HLR-6):** The app’s onboarding flow is designed for
  brevity and ease . It automates permission requests and uses sensible
  defaults (e.g. a default rule suggestion) to get a new user set up
  quickly . The backend supports quick account creation (simple
  email/pass with minimal fields) and even allows skipping account
  creation. By reducing friction (few steps, clear instructions), the
  design meets the under-2-minute onboarding target.

- **Accessibility & Privacy Options (HLR-7):** The UI design adheres to
  accessibility guidelines (WCAG 2.1 AA) by using readable text, high
  contrast, and supporting screen reader descriptors . For example, all
  images or icons (like the lock icon) have descriptive labels, and
  color alone isn’t used to convey critical information. The system also
  provides privacy controls: a **Local-Only mode** (no personal data
  upload) is available , and users can request data export or deletion
  easily (through account settings or support). The backend is built to
  honor these requests by deleting user data on demand . Collectively,
  these measures ensure the app is inclusive and respects user data
  choices.

- **Efficacy in Reducing Screen Time (HLR-8):** While actual behavior
  change depends on the user, the design’s core features directly target
  overuse. By actively locking apps after limits (especially on Android)
  and nudging the user with warnings and partner accountability, the
  system creates barriers to excessive screen time. The analytics and
  insights also help users reflect on their habits. These, combined with
  engaging notifications, are expected to achieve the goal of
  significant screen time reduction (target ≥25% after 4 weeks). The
  design allows measurement of this metric by comparing usage stats over
  time for each user.

- **User Retention and Engagement (HLR-9):** To keep users coming back,
  the app focuses on user-friendly design and tangible benefits. The
  engaging notification tones (HLR-4) and the involvement of a partner
  (HLR-5) add a human element that encourages continued use. The
  requirement of ≥70% active usage in the pilot is supported by features
  like daily summaries, motivational messages, and a sense of progress
  (users can see their improvements in the dashboard). Also, the
  system’s reliability and low performance overhead (batching data,
  quick responses) ensure the app feels smooth and trustworthy, which
  contributes to retention as an NFR. By mapping each key requirement to
  concrete design elements as above, we ensure traceability from the SRS
  to this high-level architecture .

## Diagrams

The following diagrams illustrate the high-level design, including the
deployment architecture and the limit enforcement flow:

<img src="media/image5.png"
style="width:6.50521in;height:5.71291in" />

**Figure 1: Deployment View of LockdIn** – This diagram shows the mobile
clients, backend microservices, and external integrations in the system.

In the deployment diagram above, the **Android and iOS apps**
communicate with the backend over HTTPS. The backend consists of
microservices (Auth, Usage, Rule, Notification) which share a Postgres
**database** for persistence. Internal service-to-service calls (shown
with dotted lines in the diagram) use gRPC. The Notification service
connects out to external providers: it sends push messages via
**FCM/APNs** to the mobile devices, and uses **SES/Twilio** to reach the
accountability partner via email or SMS. This modular deployment allows
independent scaling of each component and integrates with third-party
cloud services for messaging .

**Figure 2: Sequence Diagram of Limit Evaluation & Notification Flow** –
This diagram traces the steps when a user’s app usage hits a defined
limit, triggering a lock and notifications:

<img src="media/image4.png"
style="width:8.25229in;height:2.96236in" />

As shown in the sequence above, the **LockdIn app** periodically sends
usage data to the backend (Usage Service). The Usage Service writes the
data and then calls the **Rule Service** to evaluate the latest totals .
If the user has not yet hit any limit, the Rule Service replies that no
action is needed and the cycle continues. If a **limit is reached**, the
Rule Service creates a limit-exceeded event and calls the **Notification
Service** (passing the details of which rule was triggered and what to
do) . The Notification Service then **notifies the user’s device** via a
push message, which causes the app to enforce the lock immediately (e.g.
disabling the target app on Android, or showing a “times up” alert on
iOS) . In parallel, it sends an **accountability alert** to the user’s
contact via email or SMS . This sequence ensures that as soon as a user
exceeds their self-imposed limit, two things happen: the user is stopped
from further using the distracting app, and their chosen partner is
informed – reinforcing the accountability aspect. All communications
occur over secure channels and the entire flow typically completes
within seconds of the usage being reported, providing timely
intervention. The design thus meets the functional goals of strict
enforcement and notifications in a reliable, cohesive manner.

# 4. UML Diagrams

To complement the design description, this section provides UML diagrams
of the system structure and interactions. We include a **class diagram**
representing the core data model, and have already shown an activity
workflow in Figure 3. These diagrams use standard UML notation and are
labeled for clarity.

**Class Diagram – Data Model:** The figure below shows the primary data
entities (as classes) in the LockdIn system and their relationships:

<img src="media/image1.png"
style="width:7.49739in;height:5.84896in" />

*Figure 4: Simplified class diagram for key data models in LockdIn. Each
class lists important attributes. The relationships illustrate that a
User can have multiple UsageEvents, multiple Rules, and multiple
Contacts. (For brevity, some attributes and entities are omitted.)*

The detail SQL scripts are shown below:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>//// Enums<br />
<br />
Enum tone_enum {<br />
CALM<br />
FUN<br />
PROFESSIONAL<br />
}<br />
<br />
Enum platform_enum {<br />
ANDROID<br />
IOS<br />
}<br />
<br />
Enum rule_target_enum {<br />
APP<br />
CATEGORY<br />
}<br />
<br />
Enum contact_channel_enum {<br />
EMAIL<br />
SMS<br />
}<br />
<br />
Enum contact_role_enum {<br />
ACCOUNTABILITY_PARTNER<br />
FRIEND<br />
}<br />
<br />
Enum notification_type_enum {<br />
LIMIT_ALERT<br />
SUMMARY<br />
}<br />
<br />
Enum notification_status_enum {<br />
SENT<br />
FAILED<br />
BOUNCED<br />
}<br />
<br />
//// Tables<br />
<br />
Table users {<br />
user_id uuid [pk]<br />
name varchar(255)<br />
email varchar(255)<br />
tone_default tone_enum<br />
local_only_mode boolean<br />
retention_days int<br />
}<br />
<br />
Table apps {<br />
app_id uuid [pk]<br />
platform platform_enum<br />
package_name varchar(255)<br />
display_name varchar(255)<br />
category varchar(64)<br />
is_lockable boolean<br />
}<br />
<br />
Table rules {<br />
rule_id uuid [pk]<br />
user_id uuid [not null, ref: &gt; users.user_id]<br />
target_type rule_target_enum<br />
target_app_id uuid [ref: &gt; apps.app_id] // nullable if CATEGORY
rule<br />
category varchar(64) // used if CATEGORY rule<br />
daily_limit_sec int<br />
schedule varchar(255) // e.g., JSON/cron-like<br />
tone_profile tone_enum<br />
is_active boolean<br />
triggered_at_date date // optional: last triggered day<br />
}<br />
<br />
Table usage_events {<br />
event_id uuid [pk]<br />
user_id uuid [not null, ref: &gt; users.user_id]<br />
app_id uuid [not null, ref: &gt; apps.app_id]<br />
timestamp timestamptz<br />
duration_sec int<br />
location varchar(255)<br />
}<br />
<br />
Table usage_aggregates {<br />
user_id uuid [not null, ref: &gt; users.user_id]<br />
app_id uuid [not null, ref: &gt; apps.app_id]<br />
date date<br />
total_duration_sec int<br />
unlock_count int<br />
<br />
Note: "PRIMARY KEY (user_id, app_id, date)"<br />
<br />
indexes {<br />
(user_id, app_id, date) [pk]<br />
}<br />
}<br />
<br />
Table contacts {<br />
contact_id uuid [pk]<br />
user_id uuid [not null, ref: &gt; users.user_id]<br />
name varchar(255)<br />
channel contact_channel_enum<br />
address varchar(255) // email or phone<br />
role contact_role_enum<br />
notify_on_limit_exceeded boolean<br />
notify_on_daily_summary boolean<br />
}<br />
<br />
Table notification_logs {<br />
log_id uuid [pk]<br />
user_id uuid [not null, ref: &gt; users.user_id]<br />
contact_id uuid [ref: &gt; contacts.contact_id]<br />
type notification_type_enum<br />
timestamp timestamptz<br />
status notification_status_enum<br />
}</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

In Figure 4, we see the **User** class with attributes like userId
(unique identifier), name, email, etc., as well as user-specific
settings such as toneDefault (the default notification tone profile the
user prefers), localOnlyMode (whether the user opted to keep data only
on device), and retentionDays (how long their data is kept). Each User
can have many **UsageEvent** records associated (1-to-\* relationship) –
each UsageEvent represents an occurrence of app usage, with fields for
which app (appId), when (timestamp), and how long (duration) the usage
was . A User can also define multiple **Rule** entries (1-to-*): each
Rule has details about the limit, such as target type (specific app or a
category of apps), the time limit (e.g. seconds per day), an optional
schedule or time window when it’s active, and the tone to use for
notifications related to that rule . The Rule references the userId that
owns it. Additionally, a User may have multiple **Contact** entries
(1-to-*), if they add more than one accountability partner – each
Contact stores the contact’s info (e.g. name and an email address or
phone number) and perhaps the preferred notification method. This data
model supports the functional requirements: for example, the Rule
Evaluator service will use the Rule definitions and UsageEvents
(aggregated per user) to decide on locks , and the Notification
Dispatcher will use the Contact info to send emails .

*(Note: Many other tables/classes would exist in a full implementation –
e.g., a **NotificationLog** for sent notifications, an **AppCatalog**
for categorizing apps, etc. The above diagram focuses on the central
concepts to avoid clutter. The relationships shown enforce that if a
User account is deleted, their associated rules, usage data, and
contacts would also be removed, aligning with the data export/deletion
requirement of HLR-9 .)*

**Sequence/Interaction Diagram:** *(Provided earlier as an activity
diagram in Figure 3.)* We opted to illustrate the dynamic interactions
of the most critical scenario (limit enforcement) in Figure 3 under High
Level Design. That diagram effectively serves as a sequence/flow
representation of interactions between the user, app, backend services,
and decision logic. For completeness, one could also depict a detailed
sequence diagram with lifelines for User, App, UsageService,
RuleService, Contact, etc., but given the complexity, the activity
diagram already conveys the order of messages and actions:

1.  User/App -\> Usage Service (send usage data)

2.  Usage Service -\> Rule Service (trigger check)

3.  Rule Service -\> Notification Service (limit exceeded -\> send
    notifications)

4.  Notification Service -\> App (push lock command) and -\> Contact
    (email/SMS report).

The interactions follow the logical flow described in the use cases and
ensure that all components work in concert to achieve the system
behavior.

##  

# 5. Alternate Designs

During the design process, we considered several alternative
architectures and approaches, weighing their pros and cons:

**Monolithic Backend vs. Microservices:**

One option was to implement the server as a single monolithic
application (all functionality in one codebase and process) instead of
the chosen microservices architecture. The **monolithic design** would
have been simpler to develop initially (no network calls between
services, easier to deploy as one unit) and might suffice for a small
user base. However, it was deemed less flexible and scalable for this
project. By contrast, the **microservice approach** (which we chose)
enables independent scaling – for example, if usage data ingestion
(analytics) is heavy, we can scale the Usage Aggregator service
separately . It also enforces modularity: each service has a clear focus
(auth, usage, rules, notification), which improves maintainability
(teams can work on different services without stepping on each other).
The trade-off is added complexity in deployment and communication – we
had to set up inter-service gRPC and manage multiple deployables . We
judged that the benefits for reliability and future growth outweighed
the costs. In a long-term perspective, microservices allow the system to
evolve (e.g., replace the rule engine with a more advanced one or move
notification handling to serverless) without rewriting the entire
system.

**On-Device Processing vs. Cloud Processing:**

Another design decision was **where to perform the rule evaluation and
data analysis** – on the user’s device or in the cloud. An alternative
design could have been an **on-device only solution**: the app itself
monitors usage and enforces limits entirely locally (perhaps using only
built-in OS features), and the cloud would be used minimally or not at
all. This on-device approach has privacy advantages (user data never
leaves the phone) and would even work offline. However, it has
significant limitations: it would be difficult to reliably prevent
tampering (a savvy user could potentially disable the app), heavy data
analysis might drain phone battery, and crucially it would limit
features like accountability (since sending a notification to a partner
requires internet/cloud) and multi-device sync. The chosen design thus
offloads heavy processing to the **server side** – the cloud backend
aggregates data and makes decisions. This allows use of more powerful
computation (for analytics insights) and secure logic (rules are
enforced by an authority the user can’t easily bypass). That said, we
did incorporate some on-device elements for responsiveness and privacy:
for example, the app does local aggregation to reduce how often it sends
data, and if the backend is unreachable, the app can enforce a **“local
fallback”** lock based on last known rules . Overall, the hybrid
approach (client for data collection and UI, server for brains) gave the
best balance.

**Utilizing Platform-Specific Capabilities vs. Custom Implementation**

We also considered leveraging more of the **built-in OS features** for
screen time management. For instance, Apple’s Screen Time framework
could handle much of the monitoring and enforcement on iOS (with Family
controls, etc.), and Android has a “Digital Wellbeing” API. We could
have opted to simply act as a front-end to those features. The team
decided against this because it would limit customizability and the
“strictness” we wanted. Instead, we implement our own monitoring and
locking mechanisms (especially on Android using Device Admin APIs for
true lockdown) . The alternative – relying on OS Screen Time – would
have made development easier (less to implement ourselves) but at the
cost of not meeting some requirements (e.g., Android’s Digital Wellbeing
cannot truly lock apps, just warn; iOS Screen Time is not configurable
by third-party apps to notify external contacts). Our custom approach
grants us more control: for example, our app can apply humorous
notifications or send data to a friend, which the OS alone would never
do. The downside is increased complexity and the need to ensure we don’t
violate platform guidelines (we must carefully use the Device Admin API
to avoid creating a poor user experience or security issues). We chose
the custom path to fulfill the project’s unique value proposition of
“serious” enforcement and social accountability, features which platform
default tools lack.

In summary, **we chose a cloud-centric, microservices architecture with
custom on-device enforcement logic** because it best satisfied the
project goals of strict enforcement, rich analytics, and extensibility.
The monolithic or on-device alternatives were either too limited in
function or would struggle to meet non-functional needs (scalability,
data-driven insights, cross-user learning).

Our chosen architecture may be more complex, but it aligns with the
requirement for a robust, non-bypassable solution that can evolve. For
example, if in the future we want to add AI-driven habit coaching,
having a modular backend makes it easier to plug in such a module (as
another service) without disturbing the rest . Likewise, a microservices
cloud design allows us to integrate with external services (for
notifications, etc.) in a controlled manner. We conclude that the chosen
design, while not the simplest, is justified given the ambitious goals
and the need for a dependable, scalable system.

##  

# 6. Low Level Design

We now zoom into some critical modules of the system to detail their
inner workings. We will describe the responsibilities, logic, and data
handling of the following key components: **Usage Aggregator**, **Rule
Evaluator**, **Notification Dispatcher**, and **Authentication module**.
Additionally, we outline the database schema and how data flows through
these modules. Pseudo-code and error handling considerations are
included to clarify the low-level behavior.

### **Module 1: Usage Aggregator Service (Usage Tracking & Analytics Engine)**

**Responsibilities:** This backend module handles all incoming usage
data and produces aggregated usage statistics. It implements FR-2 (App
Usage Monitoring) and parts of FR-6 (Analytics Dashboard support) . Its
main functions are to record raw usage events, update summary tables,
and respond to queries for analytics.

**Inputs:** Batched usage events from the mobile app (POST
/api/v1/usage). Each event includes fields such as userId, appId
(application package name), timestamp, and duration (seconds) .
Optionally, it may include context like location or category of the app
if the client provides them. Another input is requests for analytics
data (GET /api/v1/analytics?userId=...).

**Processing & Internal Logic:** Upon receiving a batch of events, the
service iterates through each event:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>for each usageEvent in incomingBatch:<br />
validate(usageEvent) // Check required fields, auth token, etc.<br />
insert usageEvent into UsageEvents table<br />
update or insert aggregate record for (user, app, day):<br />
current_total = current_total + usageEvent.duration</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Validation includes verifying the userId is valid and the app identifier
is in an acceptable format. After writing to the **UsageEvents** table,
the service maintains an **AggregateUsage** table (or computes on the
fly). For example, it might have a table keyed by (userId, date, appId)
storing the total usage seconds for that day . If an entry exists, it
increments the duration; if not, it creates a new entry. Additionally,
there could be a **WeeklySummary** table or the service can compute
weekly totals by summing the daily records on query. The service also
triggers any needed post-processing – notably, it will call the Rule
Evaluator to check the updated usage (this can be done synchronously or
by emitting an event). In real implementation, this might be a message
or gRPC call: *“User X used App Y for Z seconds, new total today = T”*.
This prepares the ground for enforcement.

When an analytics query comes in, the service will fetch aggregated
stats from the DB (e.g. sum of last 7 days, top 3 apps by time, etc.)
and format a JSON response . Some metrics like “peakHours” or “location
patterns” might be precomputed by a background job (see FR-10) and
stored, or computed on the fly by analyzing the user’s usage
distribution.

**Data Storage:** This module primarily uses two tables:

- **UsageEvents(userId, appId, timestamp, duration, location)** – raw
  log of events.

- **UsageAggregate(userId, appId, date, totalDuration, category)** – one
  row per user-app per day (or per week) to allow quick retrieval of
  totals. This is updated incrementally.  
    
  It may also use a **CategoryAggregate** or similar for category-level
  totals if needed. These structures enable the app’s dashboard (the
  service can quickly get “today’s total” or “this week’s top apps”
  without scanning all raw events).

**Outputs:**

- For event ingestion: usually a simple acknowledgment (HTTP 200) or an
  error code if something was wrong. No complex output; the interesting
  result is side effects (DB updated, and possibly a trigger to Rule
  Evaluator).

- For analytics query: a JSON payload like:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>{<br />
"userId": "1234",<br />
"todayTotal": 7200,<br />
"weeklyTotal": 30000,<br />
"topApps": [ {"appId":"com.instagram", "time": 7200},
{"appId":"com.youtube", "time": 3600}, ... ],<br />
"peakHour": 22,<br />
"usageByCategory": [ {"category":"Social", "time":10000}, ...]<br />
}</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

This fulfils the requirement of providing daily/weekly totals, top apps,
and patterns .

**Error Handling:** If a request is malformed or missing data, the Usage
service returns a 400 Bad Request (with a message like “Invalid usage
data”) . If the userId is not found (perhaps an unauthorized app
instance), it could return 404. On internal server errors (DB down,
etc.), it returns 500. The service is designed to be idempotent – if the
app doesn’t get a success response, it will retry sending the batch
later, and the service should handle duplicates (e.g., by ignoring an
event that was already recorded, perhaps using a unique event ID to
check). This prevents data loss or double-counting on network failures .
The service also implements basic rate limiting to avoid a misbehaving
client flooding the system; e.g., if a user somehow sends usage events
too frequently, it might start rejecting or throttling after a
threshold.

### **Module 2: Rule Evaluator & Lock Enforcer**

**Responsibilities:** This module encapsulates the logic for evaluating
screen time rules and initiating lock or notification actions. It
corresponds to FR-3 (Android hard lock), FR-4 (iOS soft reminder), and
FR-5 (rule management) on the enforcement side . In short, given a
user’s current usage and their configured rules, it decides if any rule
is violated and outputs what to do (e.g. lock an app, do nothing, etc.).

**Inputs:** It can be triggered in two ways:

1.  **Direct check request** – e.g., an API call /api/v1/checkLimits
    with parameters userId, appId (the app just used), and
    usageSecondsToday (the updated total) . This might come from the
    Usage service or the app.

2.  **Periodic scan** – the service might also periodically pull from
    the database to see if any rules are exceeded (though event-driven
    is more efficient). We assume event-driven for real-time
    responsiveness.

Additionally, on start-up or when rules change, it loads the set of
rules per user from the DB. Each rule includes its thresholds and any
conditions (time window, etc.) .

**Processing & Logic:** For a given user usage update, the Rule
Evaluator will:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>rules = DB.queryRules(userId);<br />
for each rule in rules:<br />
if rule.target matches the app/category of this usage event:<br />
currentUsage = getCurrentUsage(userId, rule.target) // from cache or
DB<br />
if currentUsage &gt; rule.dailyLimit (consider time window etc.):<br />
violation = true;<br />
prepare action = (rule.platform == Android ? "LOCK" : "NOTIFY");<br />
targetApps = rule.targetApps;<br />
message = formatMessage(rule, userId);<br />
end if<br />
end for</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

If a violation is found for any rule, the service decides the
**action**. For Android, the action is LOCK – meaning the client should
lock the specified app(s). For iOS, since it cannot actually lock, the
analogous action might be NOTIFY (to show an alert). In both cases, the
service might include a **message** like “Time’s up for today on
Instagram!” which can be shown to the user . The service could also
include a code for how to unlock if allowed (some designs might allow an
override via PIN or a cooldown period as mentioned in FR-3 acceptance
criteria) , but our basic design assumes no override (or it’s handled
via app UI later).

If no rule is violated (violation = false for all rules), the service
outputs an “OK” or no-action result.

The Rule Evaluator must also handle **rule updates**: when a user adds
or edits a rule, it ensures the new rule is loaded (possibly subscribing
to a config update event or simply querying fresh each time). For
performance, it might cache rules in memory keyed by user, updating the
cache on changes.

**Outputs:** The primary output is an **Action response**. If invoked
via API, it returns a JSON like:

- {"action": "lock", "apps": \["com.instagram"\], "message": "Time's up!
  Limit reached."} for an Android lock action .

- {"action": "notify", "message": "Limit reached for Instagram – take a
  break."} for iOS or cases where only a notification is needed.

- {"action": "ok"} if no limits are exceeded .  
    
  This output is consumed by the Notification/Dispatch module or by the
  mobile app.

Additionally, if a lock action occurs, the Rule Evaluator could create a
**Log entry** in a LockEvents table (storing user, app, timestamp,
ruleID that was triggered) for auditing.

**Integration with Notification Dispatcher:** In our architecture,
rather than directly contacting the mobile device, the Rule Evaluator
will likely call the Notification Dispatcher and pass along the action
(since we centralized outgoing communications in the dispatcher). For
example, it might make an internal call:
NotifyService.handleLimitEvent(userId, action, message, contactFlag) –
where contactFlag indicates whether the user has an accountability
contact to notify. The Notification service then takes over formatting
and delivering (see next module).

**Error Handling:** If the Rule service cannot access the rules database
(e.g., DB outage), it should fail gracefully. In an API context, it
might return a special response like {"action":"error", "message":"Could
not evaluate at this time"} . The mobile app, on receiving this, might
choose to enforce a precautionary lock locally or retry after some time.
If the input data is missing or malformed (though if coming from our own
Usage module, that’s unlikely), it could return 400. The service must be
robust to race conditions – e.g., if two usage events come in quick
succession, it should handle that the usage total might have already
triggered a rule from the first event. This could involve locking at the
first trigger and ignoring subsequent triggers for the same rule until
the next day, etc. Rule state management is important: once a rule is
triggered for the day, the system might mark it as already enforced to
avoid sending multiple notifications. Such state (like “rule X already
locked today at 8pm”) can be stored in memory or a cache with expiry at
midnight.

### **Module 3: Notification & Accountability Dispatcher**

**Responsibilities:** This module is responsible for all user-facing and
external notifications. It implements FR-7 (notification tone profiles)
and FR-8 (accountability messages) . It acts as a centralized hub that
takes triggers (like “limit reached” or scheduled summary times) and
sends out appropriate messages via the correct channels.

**Inputs:**

- **Trigger events** from other services: primarily from the Rule
  Evaluator when a limit is exceeded (including info on which rule, what
  happened) , and from the Scheduled jobs (FR-10) for daily/weekly
  summary notifications.

- It also reads from the database the user’s preferences: which
  notification tone they selected, and whether an accountability contact
  is set (and that contact’s info) .

For example, an input might be an internal object or message:
LimitEvent{userId:1234, ruleId:56, app:"Instagram",
type:"dailyLimitExceeded"}.

**Processing & Logic:** When a trigger comes in:

1.  The dispatcher looks up the user’s **notification settings** (tone
    profile, contact info). Tone profile can be “Fun”, “Professional”,
    etc., which correspond to different template texts for messages.
    Let’s say the user chose “edgy” tone.

2.  It formats the **user notification** message. Using the tone
    profile, it might choose a phrase: e.g., for edgy tone: “That’s
    enough Instagram. Get back to reality 😜.” vs. a professional tone
    might say “You have exceeded your Instagram limit for today.” The
    content is generated dynamically based on the rule/app context (we
    plug in the app name, limit, time, etc.). This addresses HLR-4 by
    making notifications feel personalized .

3.  If the event is a limit exceeded and the user has an accountability
    partner, the dispatcher also generates the **accountability
    report**. This is typically a more formal summary: e.g., “John spent
    2h on Instagram today, exceeding the 1h limit.” It ensures to
    include only agreed-upon data (no sensitive specifics beyond the
    fact of limit exceeded) .

4.  The module then sends out the notifications:

    - For the **user notification**: it uses platform push messaging. On
      Android, it might call Firebase Cloud Messaging (FCM) API to send
      a data notification to the app containing the message (and
      possibly an “unlock” action if we allow the user to unlock via app
      after acknowledging). On iOS, it uses APNs similarly. If the app
      is in foreground, alternatively the message could be delivered via
      a persistent connection or immediate response – but using the
      standard push infrastructure is simpler and reliable even if app
      is background.

    - For the **contact notification**: it uses an email/SMS API. For
      email, it could use AWS SES or any SMTP service; for SMS, maybe
      Twilio. It constructs the email with a subject like “LockdIn
      Alert: Screen Time Limit Exceeded” and body with the report. Then
      it calls the provider’s API (e.g., an HTTPS POST to send email).

5.  It logs the result. The Notification service will update a
    **NotificationLog** table with entries like (userId,
    type=“limitExceeded”, contactNotified=true, timestamp, status=sent).
    This helps in auditing and in implementing any resend logic. For
    instance, if an email bounces, the log might mark status “bounced”,
    and the system could disable that contact or inform the user.

If multiple events come closely (say user exceeded two different app
limits around the same time), the service may coalesce them or apply a
**rate limit** to notifications (to avoid spamming the user or contact)
. Typically, one violation triggers one set of notifications, and then
it won’t notify again for the same rule within, say, an hour.

For scheduled summaries (e.g., “Your daily screen report” each night at
9pm), the dispatcher would similarly gather data (maybe provided by
Usage service or precomputed) and send a notification or email summary
(if user opted in for email reports).

**Outputs:** The direct outputs are the sent notifications themselves
(not something that the system returns as an API result – rather, the
effect is external). However, the module might return a status to
internal callers. For example, after sending, it could respond to the
Rule Evaluator with “notification_sent” or just an acknowledgement. More
importantly, the outcomes are recorded in logs as described.

**Error Handling:** If the push notification fails (e.g., FCM service
down or returns an error), the dispatcher can retry a few times. If a
user’s device is unreachable (perhaps uninstalled app), FCM might return
a specific error and we might mark the user’s device token as invalid.
For emails/SMS, if the third-party API call fails due to a network
issue, we queue a retry. If it fails due to bad address (bounce), we
mark that contact and perhaps stop further attempts until the user
updates it. The dispatcher should not crash on exceptions – each send
operation is wrapped in try-catch, and failures are logged but do not
halt the processing of other messages. In worst case, if dispatcher is
down, the system can temporarily function without sending notifications
(user might not get immediate feedback, but core locking could still
happen on Android since the Rule Evaluator’s command might reach the
device via a direct channel or next app sync). We also implement a
**throttle**: if a buggy loop tried to send hundreds of messages, we
detect unusual volume and break out to prevent spam. This ensures
compliance with any messaging limits and prevents runaway notification
storms.

### **Module 4: Authentication & User Management**

**Responsibilities:** This module covers user sign-up, login, logout,
and account management (password reset, etc.). It isn’t explicitly a
highlighted requirement except the need for secure authentication (part
of FR-1) , but it is critical infrastructure for the app. It ensures
only authorized users (or device-only sessions) can send data and get
data.

**Inputs:**

- **Registration requests:** e.g., POST /api/v1/register with
  user-provided email, password (or OAuth token if using Google
  sign-in).

- **Login requests:** POST /api/v1/login with credentials.

- **Token verification on each API call:** The Auth module (or an API
  gateway) intercepts other service calls to verify the user’s session
  token or API key.

**Processing:**

- For **registration**: Validate the email format and password strength.
  Create a new User entry in the database (User table with unique
  userId). The password is hashed with a salt (using a strong algorithm
  like bcrypt) . If email verification is required, generate a
  verification token and perhaps send a verification email (this could
  be done via Notification module as well). If using OAuth, verify the
  token with the OAuth provider and create a user linked to that
  identity. The result is a new account.

- For **login**: Verify the email/password against the stored hash. On
  success, create a session token (e.g., JWT or random token stored in a
  sessions table) and return it to the client. The token will be used in
  subsequent calls (e.g., as an Authorization header). The Auth service
  may also handle “anonymous device-only mode” by issuing a token tied
  to device ID without a user account.

- The Auth module also allows **password reset** (generate email with
  reset link) and **logout** (invalidate token).

**Data Storage:** In the **User** table, important fields include userId
(UUID), email, passwordHash, createdAt. There might also be fields for
preferences, which we saw in the class diagram (toneDefault,
localOnlyMode, etc.) – these could be in the User table or a separate
Preferences table. A **Session** table or cache stores active sessions
if not using stateless JWTs. If GDPR compliance is needed (part of
HLR-9), the user management module also handles data deletion: when a
user deletes their account, it triggers deletion of their associated
records (rules, events, contacts) as per FR-9 .

**Outputs:**

- Registration returns a success (possibly with token directly if we
  auto-login the user).

- Login returns an auth token and maybe user profile info.

- Auth failures return 401 Unauthorized with an error message.

- The module might also output events like “user created” that other
  parts (analytics or welcome emails) could use.

**Error Handling:** Security is paramount: on login failure (wrong
password), respond with a generic error (don’t reveal whether email was
valid or not). Use rate limiting or exponential backoff on repeated
failed logins to prevent brute force attacks. Passwords are never stored
in plaintext (only hashes) . The service should also enforce email
uniqueness. If the database is down during auth, logins may fail (which
essentially locks out users – so we’d want high availability for this
module). We could have a fallback offline mode where the app remembers
if it was recently logged in and allows some local functionality, but
generally, if auth is unavailable, the app will show an error. Sessions
are configured to expire after a reasonable period for security . The
Auth service also ensures that if a user is in “device-only” mode, no
personal data is stored server-side for them (fulfilling a privacy
option).

### **Database Design & Schema Overview**

Bringing the data pieces together, the central database (PostgreSQL)
contains tables corresponding to the classes discussed and more. A
possible schema (simplified) is:

- **User:** (userId PK, email, passwordHash, name, toneDefault,
  localOnlyMode, retentionDays, createdAt, etc.)

- **UsageEvent:** (eventId PK, userId FK-\>User, appId, timestamp,
  duration, location) – this can grow large; we may partition it by date
  or have the retention job purge old entries after X days.

- **UsageAggregate:** (userId+date+appId PK, totalDuration) – possibly
  also weekly or monthly aggregates, and maybe fields for category
  totals.

- **Rule:** (ruleId PK, userId FK-\>User, targetType \[app/category\],
  targetValue \[e.g. “com.instagram” or “Social”\], dailyLimitSec,
  weeklyLimitSec, activeSchedule \[e.g. “9:00-17:00” or null\],
  toneProfile, isActive, createdAt).

- **Contact:** (contactId PK, userId FK-\>User, name, method
  \[email/SMS\], contactInfo \[email address or phone\], verified(bool))
  – the verified flag if we send a confirmation to the contact perhaps.

- **NotificationLog:** (logId PK, userId, type \[limit_alert or
  summary\], contactId, timestamp, status \[sent, bounced, etc.\],
  messageSnippet).

Additionally, we might have:

- **Session/Token:** (tokenId, userId, issuedAt, expiresAt) if not using
  stateless JWT.

- **AppCategory:** (appId, categoryName) – a reference table if we
  classify apps by category for insights.

- **AuditLog:** if needed for admin/DevOps to see system actions.

**ER Diagram Note:** The class diagram in Figure 4 already illustrated
the core relationships: User–Rule (one-to-many), User–UsageEvent
(one-to-many), User–Contact (one-to-many). The database schema enforces
these with foreign keys. On delete cascades can be set such that if a
User is deleted, all their rules, events, contacts, etc., are deleted
(or anonymized) to meet the data deletion requirement . Indices are
added on important queries, e.g., index on UsageEvent(userId, timestamp)
to fetch a user’s recent events quickly, and on Rule(userId) since we
often query a user’s rules.

**Consistency:** We ensure that writing a UsageEvent and updating the
UsageAggregate happen in one transaction (so totals never diverge from
raw data). Similarly, when a rule is inserted, it’s immediately visible
to the Rule Evaluator on next check (we could send an invalidation
message to refresh cache). These low-level design considerations
guarantee that the system’s data remains consistent and accurate, which
is vital for user trust (imagine if the dashboard said you used 1h but
the rule locked you out as if you used 2h – that must not happen).

In pseudocode, a **daily summary job** (part of FR-10) might run at
midnight:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>for each user:<br />
totals = sum durations from UsageEvent where date = yesterday (or from
UsageAggregate)<br />
store totals in DailySummary table (userId, date, total, topApp,
etc.)<br />
purge UsageEvent where date &lt; (today - retentionDays) // to enforce
data retention limit</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

This uses retentionDays from User settings . Summaries can be used for
weekly emails or for faster dashboard queries of past days.

Through this low-level design, we ensure each module is robust: **Usage
Aggregator** efficiently handles data input/output, **Rule Evaluator**
ensures timely enforcement, **Notification Dispatcher** communicates
effectively with end-users and contacts, and **Auth** secures the
system. Each component has been considered in terms of how it fails (and
recovers), so that the overall system meets the reliability and security
requirements (e.g., using least-privilege access: each microservice only
has DB permissions it needs, etc., as noted in architecture ). This
modular breakdown also makes it easier to test components individually
(for example, we can unit test the rule evaluation logic with various
usage scenarios).

# 7. Conclusion

In conclusion, the LockdIn mobile application is structured to fulfill
its mission of curbing screen addiction through a combination of strict
enforcement and supportive analytics. The system design we’ve detailed –
comprising a feature-rich mobile client and a scalable cloud backend –
addresses the functional requirements like usage monitoring, lockdown
rules, and notifications, while also satisfying non-functional needs
such as privacy (minimizing data collected and honoring user consent) ,
security, and user experience.

By tracing high-level requirements to concrete components and data
models, we’ve ensured that each requirement (HLR-1 through HLR-9) is
accounted for in the architecture. The provided diagrams and flows
illustrate how a user moves from onboarding, to daily usage under the
system’s guidance, to receiving feedback and adapting their habits – all
enabled seamlessly by the designed modules working in concert. The
alternate designs considered provided insight into why the chosen
architecture is appropriate: it offers a robust, extensible foundation
for LockdIn’s goals, as demonstrated by our alignment with project
assumptions and constraints (e.g., leveraging Android capabilities fully
while working within iOS limitations) .

This design is positioned not only to meet the initial pilot metrics
(like 25% screen time reduction and 70% retention) but also to evolve
with future needs. For example, new features (perhaps an AI coach or
integration with wearable devices) could be added as new services
without major overhauls. In summary, the system design balances strict
control with user empowerment, aiming to deliver a reliable tool for
digital well-being. It represents a comprehensive solution that is
technically sound and grounded in the requirements and expectations set
out in the project charter and requirements specifications.

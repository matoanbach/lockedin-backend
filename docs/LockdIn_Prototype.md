# **Architectural Model**

<img src="media/media/image3.png"
style="width:8.45095in;height:5.75986in" />

We deploy LockdIn on AWS using a Kubernetes (EKS) cluster, with an
external Application Load Balancer (ALB) or Network Load Balancer
routing traffic to an NGINX Ingress controller. The ALB (or equivalent
AWS LB) performs TLS offload using ACM-managed certificates, terminating
HTTPS and handshaking with clients . The NGINX ingress then
load-balances incoming HTTPS requests to the frontend service pods
within the cluster. This design offloads encryption work to the ingress
layer for better performance . Frontend pods (Docker containers in EKS)
serve as the public API gateway or web UI, handling request parsing and
authentication. They relay data internally via gRPC to backend service
pods; gRPC (with protobuf) is used for high-performance inter-service
communication . Backend pods (Go/gRPC services) implement core logic
(usage tracking, rule evaluation, notifications). A PostgreSQL database
(Amazon RDS/Aurora) stores user settings, usage events, aggregates, and
lockdown rules. CI/CD is automated with GitHub Actions: on code push,
Actions build Docker images, push them to a private ECR, and update the
EKS deployments. All AWS resources (nodes, pods, IAM roles) follow
least-privilege: each pod has an assigned IAM role limited to needed
operations .

- **Components:** The NGINX Ingress controller terminates TLS (using ACM
  certificates) and routes traffic internally. Frontend pods handle
  public API endpoints and validate requests. Backend pods run the Usage
  Aggregator, Rule Evaluator, and Notification Dispatcher. A managed
  PostgreSQL (RDS/Aurora) holds data (encrypted at rest via AWS KMS ).
  GitHub Actions (with OIDC/IAM roles) updates container images in ECR
  and applies Kubernetes manifests.

- **Data Flow:** A user’s mobile app issues HTTPS requests (e.g. post
  usage events, fetch analytics). Traffic first hits the AWS LB and TLS
  is terminated at the NGINX ingress. The ingress forwards the request
  to the appropriate frontend service pod. The frontend validates input
  and invokes the corresponding backend service over gRPC. The backend
  then reads or writes to the Postgres DB as needed. For example, a
  POST /api/v1/usage event is processed by the Usage Engine, which
  normalizes the data and updates daily/weekly aggregates in the DB. A
  GET /api/v1/analytics request causes the Usage Engine to query
  aggregated stats and return a JSON summary. All channels use
  encryption (TLS for client-to-ingress; mTLS or TLS for internal gRPC
  as needed).

- **Security Controls:** We follow AWS best practices for containerized
  services. All external API endpoints require HTTPS with TLS
  (terminated at the NGINX ingress using ACM certs) . Container images
  reside in a private ECR registry with automated vulnerability scanning
  enabled. Each pod runs with a minimal IAM role (e.g. the backend has
  only permissions to access its database and SNS/SES, nothing extra) .
  Kubernetes NetworkPolicies can optionally be applied to restrict
  pod-to-pod traffic (allowing only needed connections) . The PostgreSQL
  database is encrypted at rest via AWS KMS (all storage, backups, and
  snapshots are encrypted ). Data in transit (between app/backend) is
  encrypted via TLS/SSL (e.g. enabling rds.force_ssl for Postgres ). We
  minimize data retention: only aggregated usage metrics are stored (in
  line with GDPR/data-minimization principles ) and older data is
  periodically purged or rolled up. All data handling adheres to a
  documented privacy policy, with retention limits as required by
  regulation.

- **Platform Constraints:** The mobile clients implement
  platform-specific lockdowns. On Android, we use the Device Admin or
  Usage Access APIs to enforce **hard** locks, so that apps are actually
  blocked at runtime (fulfilling non-bypassable lockdown requirements).
  On iOS, we use Apple’s Screen Time/DeviceActivity APIs to issue
  **soft** limits (reminders or overlays), since iOS does not allow
  third-party apps to forcibly block other apps. The client apps
  (Android and iOS) incorporate these behaviors: Android triggers a
  lockdown intent when limits are reached, while iOS simply notifies the
  user. The backend rule engine emits either a “lock” action (for
  Android) or “notify” action (for iOS) based on the platform.

- **Privacy & Data Minimization:** From design, we collect only
  necessary usage metadata (app identifiers, durations, timestamps) and
  minimal user identifiers, always with explicit user consent . Raw logs
  are never stored unaggregated; instead, the Usage Engine updates
  roll-up counters (e.g. daily totals per app) so that only summaries
  are persisted. Wherever possible, data is kept on-device (the app can
  compute some aggregates locally and only send summaries). This
  “privacy-by-design” approach aligns with data-minimization principles:
  personal data is “adequate, relevant and limited to what is necessary”
  . All permissions and data uses are clearly explained in first-run
  screens and settings (consent-first design).

#  

# **User Interface Model (Front End)**

<img src="media/media/image1.png"
style="width:3.18229in;height:8.00299in" /><img src="media/media/image2.png"
style="width:3.18991in;height:7.97972in" />

LockdIn provides native mobile apps for Android and iOS (and an optional
web UI) that focus on usability and accessibility. The apps offer an
intuitive onboarding flow (≤2 minutes setup) that requests only
necessary permissions and explains data usage clearly (meeting
quick-start goals). The main UI features include:

- **Analytics Dashboard:** A visual summary of screen time and app
  usage, showing daily/weekly totals, top used apps, and usage patterns
  (e.g. peak hours). Users can drill into categories and time ranges.
  This fulfills requirements for behavioral insights (HLR-3, HLR-10).
  The dashboard uses charts and lists with clear labels.

- **Rule Setup & Settings:** Screens where users define custom lockdown
  rules (e.g. “limit Instagram to 2 hours/day”). The UI lets users
  select apps or categories and set timers. Separate sections allow
  choosing notification tone profiles (HLR-4) and managing
  accountability contacts (HLR-5). All settings follow a clean,
  accessible layout (large touch targets, logical grouping).

- **Onboarding & Consent:** On first launch, the app presents an
  onboarding wizard that explains its purpose (“digital well-being
  tool”), asks for necessary permissions (e.g. usage access or device
  admin on Android), and obtains consent for data collection . This
  respects privacy requirements (HLR-15) by being explicit about what is
  collected and why.

- **Notifications UI:** When limits are reached, the app displays a lock
  screen (Android) or alert (iOS) with the configured message/tone.
  Users can also trigger manual notifications to accountability
  contacts. Tone and reminder templates are user-selectable in settings.

- **Accessibility:** The app is designed to meet WCAG 2.1 AA standards
  for mobile apps . For example, it uses high-contrast colors, scalable
  fonts, and accessible labels. The interface supports screen readers
  and keyboard navigation where applicable. UI elements are sized for
  touch and laid out for readability (WCAG 2.1’s mobile criteria for
  “small screen sizes” and contrast) .

Overall, the front-end design emphasizes a friendly user experience
(HLR-12) with clear calls-to-action (lock now, view stats, set limits)
and inclusive design. The mobile UI is distinct on Android vs. iOS to
match each platform’s conventions, but core flows (analytics, rule
creation, notifications) are consistent across both.

#  

# **Algorithmic Model (Back End)**

Our back-end consists of microservices (Go/gRPC) that implement the core
algorithms. Major components include:

- **Usage Tracking & Aggregation Engine (HLR-1, HLR-3):** This service
  ingests usage events from clients and maintains aggregated stats.

  - *Input:* JSON events like {userId, appId, timestamp,
    durationSeconds, location?, category?} sent by the mobile app.

  - *Processing:* Each event is validated (check user permissions, app
    ID) and inserted into Postgres. The engine updates rolling
    aggregates (daily/weekly screen time per app or category).
    Background jobs compute trends (peak usage hours, location-based
    patterns) for insights.

  - *Output/API:* Provides endpoints such as GET
    /api/v1/analytics?userId=XYZ that return a JSON summary (fields like
    todayTotal, weeklyTrend, topApps\[\], peakHours\[\]). This is used
    by the front-end to display charts.

  - *Sample API:*

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th># Post a usage event<br />
curl -X POST https://api.lockdin.example.com/api/v1/usage \<br />
-H "Content-Type: application/json" \<br />
-d
'{"userId":"1234","appId":"com.social.app","duration":600,"timestamp":"2025-11-02T18:23:00Z"}'<br />
# Get aggregated analytics<br />
curl https://api.lockdin.example.com/api/v1/analytics?userId=1234</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- *Errors:* The API returns 4xx for bad requests (missing fields,
  malformed JSON), 404 if the user is unknown, and 500 on server/DB
  errors. If a new user has no data, the analytics endpoint returns
  zeros or empty lists.

<!-- -->

- **Rule Evaluator & Lock Enforcer (HLR-2, HLR-13, HLR-14):** This
  service applies user-defined limits and issues lock/notify actions.

  - *Input:* Periodic usage updates or events from the app (e.g. “user X
    has used app Y for Z seconds today”) plus the user’s configured
    rules from the database (e.g. “max 2h/day on Instagram”).

  - *Processing:* For each update, it fetches relevant rules and
    compares usage to limits. If usage ≥ limit, it triggers the
    appropriate action. On Android, it sends a lock command (via push
    notification or gRPC callback) so the client calls the device admin
    API to block the app. On iOS, it instead sends a reminder/alert
    message (since true enforcement isn’t allowed). The service logs
    lock events for auditing.

  - *Output/API:* Returns a JSON action for the app. Examples include
    {"action":"lock","apps":\["Instagram"\],"message":"Time’s up!"} for
    Android, or {"action":"notify","message":"Reminder: limit reached!"}
    for iOS. If under limits, it returns {"action":"ok"}.

  - *Sample API:*

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>curl -X POST https://api.lockdin.example.com/api/v1/checkLimits
\<br />
-H "Content-Type: application/json" \<br />
-d
'{"userId":"1234","appId":"com.social.app","usageSecondsToday":7200,"timestamp":"2025-11-02T20:00:00Z"}'</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- *Errors:* Returns 400 if required fields are missing, 404 if no rule
  exists (treated as no action), or 500 on internal errors. If rule
  lookup fails (e.g. DB down), it responds
  {"action":"error","message":"Try again later."}.

<!-- -->

- **Notification & Accountability Dispatcher (HLR-4, HLR-5):** This
  service sends messages when limits are hit or on schedule.

  - *Input:* Triggers from the Rule Evaluator (limit exceeded) or
    scheduled tasks (daily/weekly summaries). It also reads user
    settings (notification tone profile, opted-in contacts for
    accountability).

  - *Processing:* It formats a message according to the chosen tone
    (e.g. “Time’s up!” vs. “Reminder: almost at your limit!”). If the
    user enabled accountability, it sends an email/SMS report to the
    chosen contact; otherwise it only sends a push notification to the
    user. The dispatcher records each sent notification in the DB for
    history.

  - *Output/API:* Initiates delivery via push or email/SMS. The service
    API returns success status, e.g.
    {"status":"sent","detail":"Notification delivered."}.

  - *Sample API:*

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>curl -X POST https://api.lockdin.example.com/api/v1/notify \<br />
-H "Content-Type: application/json" \<br />
-d
'{"userId":"1234","tone":"edgy","type":"limitExceeded","contactEmail":"friend@example.com"}'</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- *Errors:* Returns 400 if parameters are missing, 404 if user/contact
  not found, 429 if rate limits exceeded, 500 if the notification
  service fails. Bounced emails are logged for retry or disabling that
  contact.

Each component above is linked to our high-level requirements (see
traceability below). Together, the algorithmic services implement the
business logic: tracking usage, enforcing rules (hard-lock on Android,
soft notify on iOS), and dispatching notifications, all while respecting
user preferences and privacy.

#  

# **Requirements Traceability**

We ensure every high-level requirement (HLR) is covered by our
architecture:

- **HLR-1 (Usage Monitoring):** Satisfied by the Usage Tracking &
  Aggregation service (backend) which records daily/weekly totals, and
  by the mobile analytics dashboard (front end).

- **HLR-2 (Custom Lockdown Rules):** Addressed by the mobile app’s
  rule-setup UI and the backend Rule Evaluator (plus Android Device
  Admin API for enforcement).

- **HLR-3 (Behavioral Insights):** Provided by the backend analytics
  engine (computing trends/locations) and the analytics UI in the app.

- **HLR-4 (Notification Tone Profiles):** Implemented via the app’s
  settings UI (tone selection) and the backend Notification Dispatcher
  (which uses tone templates).

- **HLR-5 (Accountability Contacts):** Covered by the app’s
  contact-management UI and the backend dispatcher, sending reports to
  user-specified contacts.

- **HLR-6 (Quick Onboarding):** Met by a streamlined mobile app UX with
  clear instructions and consent prompts, ensuring setup in under 2
  minutes.

- **HLR-7 & HLR-18 (Accessibility):** The mobile UI follows WCAG 2.1 AA
  guidelines (e.g. readable text, color contrast, screen-reader
  support).

- **HLR-8 (Screen Time Reduction):** An outcome metric tracked by the
  backend analytics (used to evaluate product success).

- **HLR-9 (User Retention):** Measured via analytics (app launch and
  usage events captured by backend).

- **HLR-10 (Analytics Views):** Supported by the app’s analytics screen
  and the backend API that serves analytics data.

- **HLR-11 (Accountability Enablement):** Driven by the settings UI (to
  opt in) and the backend dispatch (to send alerts).

- **HLR-12 (Satisfaction ≥4.0):** Achieved by focusing on polished UI/UX
  in the mobile app (responsive design, intuitive workflows).

- **HLR-13 (Android Lockdown):** Implemented by the Android client
  (using DeviceAdmin or LockTask APIs) and the backend rule engine
  triggering locks.

- **HLR-14 (iOS Soft Limits):** Implemented by the iOS client (using
  ScreenTime/DeviceActivity APIs) and backend notifications.

- **HLR-15 (Data Minimization & Consent):** Enforced by only collecting
  minimal usage metadata (mobile app consent screens) and by backend
  policies that store aggregated data only .

- **HLR-16 (\<5% Crash Rate):** Ensured via robust app development and
  automated backend monitoring (crash analytics).

- **HLR-17 (Privacy & Retention):** Handled through the mobile privacy
  settings UI (user controls) and backend data management (automatic
  roll-ups and purges).

#  

# **Societal Impact & Ethics (IE.2)**

LockdIn is designed to have positive social impact by combating
**digital distraction**. Excessive smartphone use has been linked to
reduced concentration, increased stress and anxiety, and lower
productivity . For example, medical experts note that constant digital
interruptions “fragment our cognitive processes, leading to decreased
productivity and increased stress” . By enforcing usage limits and
encouraging mindful device use, LockdIn helps users reclaim time for
offline activities and focus on what matters, aligning with our goals of
“healthier screen habits” and improved well-being.

Ethically, we prioritize **privacy-by-design**. We collect only what is
necessary: anonymized usage counts and app identifiers, never personal
content or raw logs. This aligns with data-minimization principles (e.g.
GDPR’s rule that data must be “adequate, relevant and limited to what is
necessary” ). All data collection is explicit and opt-in: users consent
to provide usage access or device admin rights when they install the
app. Usage data is stored in aggregated form, and we implement strict
retention policies (data is purged or rolled up after use).
Accountability features are strictly opt-in: users must explicitly add a
contact before any report is shared. All data transmissions and storage
are secured (encrypted) and fully documented. In sum, LockdIn delivers
real benefits (less distraction, better habits, higher productivity)
while respecting autonomy and privacy: we operate with transparency,
limit data to the bare minimum , and give users control over their
information (consistent with our charter’s privacy commitments).

**Sources:** Our design follows AWS/Kubernetes best practices for
architecture and security . We use cloud-native patterns (Ingress
controllers, managed databases) and adhere to AWS security guidelines
(TLS, encryption, least-privilege IAM) . Accessibility and UI design
meet established standards (WCAG 2.1 for mobile) . Digital well-being
research (e.g. on screen-time impact ) and privacy regulations (GDPR
data-minimization ) guided our ethical framework. All content above is
based on these principles and up-to-date sources.

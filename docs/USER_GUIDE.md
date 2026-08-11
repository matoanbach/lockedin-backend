# LockdIn User Guide

LockdIn is an Android-focused digital-wellbeing application. It records recent app usage, displays
dashboard and trend summaries, lets a user set per-app time limits, and can show warnings or a soft
intervention when a configured limit is reached.

This guide is written for a tester or evaluator who does not need to understand the source code.

## Before You Start

You need:

- an Android device or emulator;
- the LockdIn debug build installed;
- the LockdIn backend and PostgreSQL running;
- the device signed into the same private tailnet as the Windows host and able to reach the stable
  `https://<machine>.<tailnet>.ts.net` backend URL;
- Android Usage Access if you want real device-usage synchronization.

Optional permissions:

- **Notifications**: enables visible warning notifications.
- **Accessibility**: enables live foreground-app tracking and soft interventions. Grant it only
  when the test requires it.
- **Picture-in-Picture**: belongs to individual media apps such as YouTube; LockdIn does not need
  to change this setting.

The Phase D build has a **Sign in or create account** screen. It opens the configured Keycloak page
in the system browser; LockdIn never asks for the password inside the app. Use only a prepared local
test identity. The seeded default profile is demo-only and is not an authenticated account. The
current mobile scope supports one account per app installation. After an account has been used on
the device, the welcome screen offers only **Sign in** for that account and does not reveal its
identity while signed out. To use a different account, delete the current account first. Same-device
multi-account switching is future development.

## First Launch

1. Start the backend and authentication provider, then confirm the health endpoint works.
2. Open LockdIn and complete system-browser sign-in with a prepared test identity.
3. If prompted about usage recorded before sign-in, choose **Import** or **Discard**; it will not
   upload until you decide. Then read the welcome screen and continue.
4. Review each requested Android permission. Android opens the relevant system Settings page;
   return to LockdIn after making your choice.
5. Choose a default daily limit.
6. Complete setup to open the dashboard.

If the seeded development database is already in use, onboarding may already be marked complete
and the app will open the dashboard directly.

## Dashboard

The dashboard shows:

- today's total recorded usage;
- category totals;
- weekly usage;
- Android usage-sync status;
- shortcuts to Trends, Rules, and Accountability;
- settings in the header; and
- a visible **View Weekly Summary** action.

Category names are assigned from a curated, package-based descriptive taxonomy such as **Social &
Messaging**, **Video & Entertainment**, and **System & Utilities**. They organize comparable
analytics; they do not judge whether an app or behavior is productive, good, or bad. Unknown
packages retain useful supplied names and categories when available. Arbitrary category creation
and per-app category reassignment are not available in the current build. Tap a category card to
see the friendly app names, package identifiers, and exact display durations contributing to that
category today.

To synchronize manually:

1. Confirm **Usage Access** is allowed.
2. Open the dashboard.
3. Tap **Sync Recent Usage**.
4. Wait for the collected, created, and duplicate counts.
5. The dashboard and rule status refresh automatically after a successful sync.

LockdIn also attempts an automatic sync when the app resumes. A later manual sync may correctly
show zero new events if the automatic sync already imported them.

Dashboard usage belongs to the signed-in account's profile. Creating an account does not reset
Android's device-level UsageStats, but a new account does not inherit usage already owned by another
LockdIn account. Usage recorded before sign-in remains unclaimed until the user explicitly chooses
**Import**; choosing **Discard** does not assign it to the account. When Accessibility is enabled,
manual sync drains that account's live queue instead of backfilling the device's complete Android
history, which avoids silently transferring another account's activity or counting it twice. After
a successful sync, the refreshed dashboard value should appear within seconds.

## Rules

Use **Rules** to create, edit, enable, disable, or remove a per-app daily limit.

1. From the dashboard, tap **Add Rule** to open the creation form directly. Tap **Rules** instead
   when you want to open the rules overview without immediately opening the form.
2. From the overview, use **Add Rule** when you are ready to create another rule.
3. Select a known application.
4. Set a positive time limit.
5. Save the rule.
6. Use the switch to enable or disable it.

Current known app choices include Instagram, YouTube, Messages, Spotify, and TikTok. The backend
rejects a second rule for the same application.

Rule behavior is soft enforcement. Android platform constraints, force-stop, permission removal,
device policy, and OEM behavior can prevent absolute blocking.

## Trends and Weekly Summary

- Tap **Trends** to view hourly usage, seven-day activity, top apps, and one contextual **Peak Usage
  Window** insight. Weekly-chart labels use a consistent whole-hour scale.
- Tap **View Weekly Summary** on the dashboard to open **Weekly Summary**.
- Weekly Summary shows total time and daily average. **Weekly Highlights** contains exactly two
  summaries: **Goal Progress** and **Best Streak**.

The previous non-persistent rating and feedback controls were removed. The current build does not
collect or measure user satisfaction.

Current limitation: once any usage history exists, missing dates are treated as zero-usage
successful days by the goal/streak calculation. Synchronization or data-gap days can therefore be
counted as successful.

## Accountability

The Accountability screen stores a contact email inside the authenticated principal's profile.

1. Open **Accountability**.
2. Enter a valid email address.
3. Add the contact.
4. Remove a contact using the available delete action.

The system stores the contact but does not currently send email, invitations, reports, or
notifications to that person. Confirm consent before entering a real person's address.

## Settings

The settings area provides links for:

- Usage Access;
- notification permission and diagnostics;
- Accessibility service;
- text size, high contrast, and larger tap targets;
- privacy information;
- sign out, which stops uploads and clears secure session material and account-scoped caches; and
- **Delete account**, which requires typing `DELETE` and a fresh system-browser sign-in for the same
  active account. Successful deletion removes the provider identity, profile-owned backend data,
  secure session, account binding, and that account generation's local queued data. Retained security
  evidence is de-identified.

The current repository does not provide the separate external web deletion-request resource needed
for a public store release. That release requirement must be completed with an approved public URL
and retention policy before production distribution.

Changing an Android permission is a user-controlled system action. LockdIn opens Settings but does
not silently grant the permission.

## Common Messages

| Message or state | Meaning | What to do |
| --- | --- | --- |
| `Authentication unavailable` | The app cannot validate the saved session or reach the configured authentication boundary | Verify backend/provider availability and retry; do not bypass the route guard |
| `Sign in again` | Renewal failed or the saved credential is no longer usable | Complete system-browser sign-in again |
| `Could not connect to the backend at ...` | Network or backend connection failed | Check Tailscale on both devices, Docker/container health, Tailscale Serve status, and the compiled frontend `.env` origin |
| `Grant Usage Access before syncing...` | Android usage permission is missing | Open Device Permissions and grant Usage Access |
| `The backend could not be reached...` or an authenticated-session upload error | A queued Accessibility event could not be uploaded | Check the backend and private network, or sign in again when prompted, then retry |
| `Uploaded ... but ... remain after the safe per-sync limit` | More than 300 queued Accessibility events were available | Tap **Sync Recent Usage** again to drain the remaining account-owned events |
| `Live usage upload made no progress...` | The native queue could not advance even though no upload failure was reported | Reopen LockdIn and retry; if it persists, collect diagnostics |
| Manual sync reports `0/0/0` | No new completed sessions were found | This is normal after automatic sync |
| A rule already exists | The app already has a configured rule | Edit the existing rule instead |
| Invalid email | Accountability contact validation failed | Enter a complete email address |

## Offline Behavior

If the backend is unavailable:

- the app displays a clear connection error;
- failed uploads do not advance the successful-sync watermark;
- queued live events remain available for retry;
- reconnecting and reopening LockdIn triggers another synchronization attempt.

Do not clear app data as a normal troubleshooting step; doing so removes local preferences,
watermarks, and pending state.

## Privacy and Safety

- Usage history and accountability contacts are personal information.
- Use demo addresses and test accounts during presentations.
- Do not expose the local stack to the public internet or enable Tailscale Funnel. The private
  tailnet edge is for the current development/thesis prototype and is not production hardening.
- Do not display notifications containing private information during screen sharing.
- Do not reset the Docker volume unless all stored data may be deleted.
- Do not enable Accessibility solely for a presentation unless the feature is part of the planned
  demo and the device owner has approved it.

## Frequently Asked Questions

### How does login work?

The system browser handles Keycloak login using Authorization Code + PKCE. LockdIn stores rotating
tokens in platform-backed secure storage, validates the backend session, and enables only rows owned
by that account generation. An isolated August 8, 2026 Samsung SM-A528B run physically verified the
registration and normal sign-in pages, redirect back to LockdIn, protected-session bootstrap,
authenticated onboarding, and sign-out that remained cleared after an app-process restart. A
successful refresh after a long-offline provider session, backup/restore behavior, and real SQLite
v1-to-v2 migration remain unverified.

### Why does a short session sometimes appear as one minute?

Raw usage events retain timestamp precision, while some dashboard values are displayed as whole
minutes. Display rounding does not mean the raw interval was recorded as a full minute.

### Does usage restart when I create a new account?

Android's device usage counter does not restart, but LockdIn analytics are isolated by account and
profile. A new account starts with its own subsequently recorded usage plus any unclaimed local
usage the user explicitly imports; it does not inherit a previous account's history. The number of
raw uploaded events is also not a minute count: Today's Screen Time uses the current profile, local
calendar-day boundaries, and non-overlapping aggregate durations.

### Why did a session appear after a later sync?

Android may publish its final stop event after LockdIn first checks. LockdIn keeps its completed
session watermark behind unfinished activity so a later sync can recover the full session.

### Will usage still appear if I do not open LockdIn for several days?

With Usage Access granted and Accessibility disabled, LockdIn synchronizes when the authenticated
app opens or resumes and can recover at most the previous three days. Reopening it within that
window should add the recovered sessions to Weekly Summary. If it remains unopened longer, earlier
unsynchronized days can be incomplete because Weekly Summary displays backend-synchronized history
rather than estimating missing usage.

When the optional Accessibility service is enabled, it can capture and queue foreground intervals
while the LockdIn UI is closed. Those intervals are included after they are uploaded. Usage Access
must remain granted for either collection path.

### Why can Accessibility and UsageStats disagree about the foreground app?

Android sources may attribute a transition to different packages. LockdIn subtracts all already
uploaded live intervals from fallback UsageStats ranges to prevent counting the same wall-clock
time twice.

### Can LockdIn guarantee that an app is impossible to use?

No. Enforcement is intentionally a soft intervention. Android permissions, force-stop, OEM
behavior, safe mode, multiple profiles, and removal of Accessibility access can bypass it.

### Does the accountability partner receive an email?

No. The current build stores the contact only; outbound email is not implemented.

### Is the current build production-ready?

No. It is a tested local/demo prototype. Authentication, authorization, HTTPS deployment,
production secrets, release signing, monitoring, backups, migrations, and stronger operational
controls remain future work.

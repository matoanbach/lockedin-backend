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
- the device able to reach the backend URL;
- Android Usage Access if you want real device-usage synchronization.

Optional permissions:

- **Notifications**: enables visible warning notifications.
- **Accessibility**: enables live foreground-app tracking and soft interventions. Grant it only
  when the test requires it.
- **Picture-in-Picture**: belongs to individual media apps such as YouTube; LockdIn does not need
  to change this setting.

LockdIn does not currently have a login screen. The backend supplies one default development
profile, so no username or password is required.

## First Launch

1. Start the backend and confirm the health endpoint works.
2. Open LockdIn.
3. Read the welcome screen and continue.
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
and per-app category reassignment are not available in the current build.

To synchronize manually:

1. Confirm **Usage Access** is allowed.
2. Open the dashboard.
3. Tap **Sync Recent Usage**.
4. Wait for the collected, created, and duplicate counts.
5. The dashboard and rule status refresh automatically after a successful sync.

LockdIn also attempts an automatic sync when the app resumes. A later manual sync may correctly
show zero new events if the automatic sync already imported them.

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

The Accountability screen stores a contact email associated with the default profile.

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
- privacy information.

Changing an Android permission is a user-controlled system action. LockdIn opens Settings but does
not silently grant the permission.

## Common Messages

| Message or state | Meaning | What to do |
| --- | --- | --- |
| `Backend unavailable` | The app cannot load the default profile | Start the backend, verify the configured URL, then tap **Retry** |
| `Could not connect to the backend at ...` | Network or backend connection failed | Check Wi-Fi, host IP, firewall, container health, and frontend `.env` |
| `Grant Usage Access before syncing...` | Android usage permission is missing | Open Device Permissions and grant Usage Access |
| `Live usage uploads are still pending...` | Accessibility events remain queued | Keep the backend reachable and retry |
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
- Do not expose the current unauthenticated backend to the public internet.
- Do not display notifications containing private information during screen sharing.
- Do not reset the Docker volume unless all stored data may be deleted.
- Do not enable Accessibility solely for a presentation unless the feature is part of the planned
  demo and the device owner has approved it.

## Frequently Asked Questions

### Why is there no login?

Authentication and multi-user roles are outside the implemented prototype scope. The backend uses
one default profile. This is a known limitation and must be addressed before public deployment.

### Why does a short session sometimes appear as one minute?

Raw usage events retain timestamp precision, while some dashboard values are displayed as whole
minutes. Display rounding does not mean the raw interval was recorded as a full minute.

### Why did a session appear after a later sync?

Android may publish its final stop event after LockdIn first checks. LockdIn keeps its completed
session watermark behind unfinished activity so a later sync can recover the full session.

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

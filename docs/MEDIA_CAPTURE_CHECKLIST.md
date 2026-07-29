# Screenshot and Video Capture Checklist

The repository currently has no verified product screenshots or walkthrough video. Use this
checklist to create real media from a controlled demo build.

## Privacy Rules

Before recording:

- use seeded or synthetic data only;
- use `partner@example.com`, not a real contact;
- hide personal notifications and status-bar content;
- close unrelated apps;
- confirm no tokens, passwords, local IP addresses, or personal usage history are visible;
- keep Accessibility disabled unless the recorded step specifically demonstrates it;
- obtain the device owner's approval before changing Android permissions.

Do not use generated mockups as evidence of implemented behavior.

## Required Screenshots

Save optimized PNG files under `docs/assets/screenshots/`:

| File name | Required view |
| --- | --- |
| `01-onboarding-welcome.png` | Welcome screen and value proposition |
| `02-permissions.png` | LockdIn permission explanation screen, not private Android settings |
| `03-dashboard.png` | Dashboard with seeded realistic usage |
| `04-usage-sync.png` | Successful usage-sync summary |
| `05-rules.png` | Rule list with enabled and disabled examples |
| `06-rule-edit.png` | Rule limit editing |
| `07-trends.png` | Hourly and weekly trend views |
| `08-weekly-summary.png` | Weekly summary metrics |
| `09-accountability.png` | Demo contact only |
| `10-display-accessibility.png` | Text size/high-contrast controls |
| `11-offline-error.png` | Clear backend-unavailable state |
| `12-validation-error.png` | A clear invalid-input message |

Acceptance criteria:

- consistent device orientation and dimensions;
- no clipped text or open keyboard unless relevant;
- text remains legible in the final document;
- captions describe what is demonstrated, not just the screen name;
- media reflects the same commit used for the presentation.

## Walkthrough Video

Recommended length: 4–6 minutes.

1. State the problem and intended user.
2. Open the dashboard with seeded data.
3. Synchronize usage and explain idempotency.
4. Create or edit a rule.
5. Show Trends and Weekly Summary.
6. Add a demo accountability contact.
7. Demonstrate one validation error.
8. Demonstrate the offline message or explain it using a pre-recorded clip.
9. End with limitations and privacy safeguards.

Record permission changes as separate clips so a failed system dialog does not disrupt the main
walkthrough. Keep an offline copy of the final video for the defense.

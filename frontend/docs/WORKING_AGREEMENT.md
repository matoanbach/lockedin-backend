# Working Agreement

## Purpose

This repository serves as both our software development project and an example repository for future student teams to follow. As such, all team members are expected to maintain a professional standard in communication, documentation, coding practices, and collaboration.

Planning, task ownership, and review expectations should be balanced across all four members.

---

## 1. Team Meetings

### Weekly Scrum Meetings

- Meetings will take place every **Monday at 7PM EST**.
- Additional meetings may be scheduled as needed by the team.
- All meetings will be conducted through our **Discord server - The Great Lockin** unless otherwise specified.

### Attendance Expectations

- All team members are expected to attend meetings on time and actively participate.
- Team members should notify the group preferably 1 day prior or early as possible if they cannot attend.

### Team Etiquette
- Team members will treat each other with respect, listen actively, and be open to feedback.
- All members should value teamwork and are willing to work together to resolve conflicts or technical challenges.
- Each team member will be accountable for their assigned tasks and will communicate proactively if issues arise.

### Penalties

#### Missing Meetings

If a member misses a meeting without prior notice, the team will apply the following:

- A short written update must be posted in Discord within 24 hours
- Blocked tasks are reassigned temporarily so sprint progress continues
- The member must complete a defined catch-up task before the next meeting

#### Late Attendance

- Arriving more than **10 minutes late** without prior notice counts as a late attendance.
- Repeated lateness will trigger a one-on-one check-in with the team to identify blockers and agree on a reliability plan.

#### Repeated Absences and/or Lateness

- Multiple unexcused absences will be documented by Jasleen K. and discussed as a team.
- If the pattern continues after multiple team discussions, the issue will be escalated to the instructor/project supervisor.

---

## 2. Communication Rules

### Primary Communication Channel

- Discord will be used for:
  - Team communication
  - Meeting coordination
  - Sprint discussions
  - Technical questions
  - Announcements

### Response Expectations

- Team members should respond to important messages within:
  - **24 hours during weekdays**
  - **48 hours during weekends**

### Professional Conduct

All members are expected to:

- Be respectful during discussions
- Avoid hostile or dismissive language
- Accept constructive criticism professionally
- Help maintain a collaborative environment

---

## 3. Branching and Pull Requests

### Main Branch Protection

- Direct pushes to the `main` branch are **strictly prohibited**.
- All changes must be merged through a **Pull Request (PR)** reviewed by another team member.
- All PRs should be posted in the discord server.

## Branch Naming Convention

Branches must follow this format:

```text
type/short-description
```

Allowed branch types:

- `feature`: Adding any new functionality or a user-facing enhancement.
- `bugfix`: Urgent fixes for defects that need to be merged immediately.
- `hotfix`: Updates to existing functionality.
- `docs`: Documentation-only updates (README, setup guides, policies).
- `test`: Adding or updating tests without changing feature behavior.

Naming rules:

- Use lowercase letters only
- Use hyphens between words (no spaces or underscores)
- Keep names short and specific
- Start with the main task first, then details

Examples:

```text
feature/usage-analytics-dashboard
bugfix/lock-screen-timeout-error
hotfix/lock-screen-button-update
docs/api-setup-guide
test/add-auth-service-tests
```

### Pull Request Rules

Before opening a Pull Request:

- Code must compile successfully
- Automated tests, once setup, must pass
- Relevant documentation must be updated
- The branch must be up to date with `main`

### PR Review Requirements

- Every Pull Request must be reviewed by at least **one other team member**
- Approving member shall comment "approved" on the PR
- A copilot review **must** be performed as well
- Authors should not merge their own PR without approval unless explicitly authorized
- Review comments should be addressed before merging
- No changes should be made to the code once the PR is approved

### Merge Strategy

- Keep commit history clean
- Commit messages should be descriptive and meaningful

Examples:

```text
Add JWT authentication middleware
Fix memory leak in file parser
Update README with setup instructions
```

---

## 4. Coding and Documentation Standards

### Markdown Standards

- All documentation must use **standard GitHub-compatible Markdown**
- Only syntax properly rendered by GitHub should be used
- Avoid HTML unless absolutely necessary

### Documentation Expectations

The repository should always contain:

- A clear `README.md`
- Setup instructions
- Build/run instructions
- Contribution guidelines
- Example usage where applicable

### Code Quality Expectations

Team members are expected to:

- Write readable and maintainable code
- Use meaningful variable and function names
- Avoid unnecessary complexity
- Add comments where clarification is needed

---

## 5. Deliverables and Deadlines

### Early Submission Requirement

Deliverables should be completed **at least 48 hours before deadlines** whenever possible.

This allows time for:

- Peer review
- Testing
- Bug fixes
- Documentation updates

### Responsibility of Contributors

The contributor is responsible for:

- Verifying their code works
- Updating documentation
- Responding to review feedback promptly
- Coordinating handoff early if they cannot complete assigned work in the sprint

### Incomplete Deliverables

Pull Requests submitted too close to deadlines may:

- Be rejected from the sprint
- Be deferred to the next iteration
- Receive limited review due to time constraints

---

## 6. Automated Testing

### Testing Expectations

All major deliverables should include:

- Automated tests where appropriate
- Validation of expected behavior
- Regression protection for existing features
- For new features, include at minimum one happy-path test and one edge or error-path test

For this project, major deliverables include:

- New user-facing features
- Changes to authentication, data handling, or core business logic
- Refactors that affect existing behavior

### Required Before Merge

A Pull Request should not be merged if:

- Existing tests fail
- New features are untested
- The build pipeline is broken
- Required CI workflow checks have not passed

If a test must be deferred due to a blocker, the PR must include:

- A clear reason for deferral
- A follow-up task/ticket reference
- Explicit approval from at least one reviewer

#### Preferred Testing Workflow

- Run tests locally before pushing
- Use GitHub Actions (or equivalent CI tools) whenever possible
- Keep tests lightweight, repeatable, and maintainable

---

## 7. Repository Professionalism

Since this repository serves as an example for future teams:

- Documentation should remain polished
- Commit history should remain clean
- Pull Requests should remain professional
- Issues should be descriptive and properly labeled

The goal is to demonstrate professional software development practices that future students can learn from and emulate.

---

## 8. Conflict Resolution

If disagreements occur:

1. Discuss the issue respectfully as a team
2. Attempt to reach consensus or majority vote
3. Escalate unresolved issues to the instructor/project supervisor if necessary

---

## 9. Agreement Acceptance

By contributing to this repository, all team members agree to follow this working agreement and uphold the professional standards outlined within this document.
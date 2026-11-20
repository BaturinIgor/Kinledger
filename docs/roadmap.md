# Roadmap

Full plan with reasoning: [Kinledger: plan by version](https://claude.ai/artifact/BzSGDgEMfrrHsGM31AbaQU).

| Version | Target | Theme |
| --- | --- | --- |
| 1.0 | before 2027-01-20 | iPhone only. Must have: log, money, monthly report, US medical-expense export, no data loss |
| 1.1 | March 2027 | Family nearby: siblings reply to the report, second caregiver, reminders, several parents, UK/EU/CA/AU formats |
| 1.2 | May 2027 | Faster: lock-screen timer, home widget, document vault, who-owes-whom, calendar sync, search |
| Android | not planned for now | Revisit only with a separate decision; the backend and report page stay platform-neutral |
| 2.0 | autumn 2027 | Family account with roles, paid-helper hours, yearly report, plain-language monthly summary, Spanish |

## 1.0 must have

- Onboarding: who you care for, sign in with Apple (no Google sign-in for now).
- Quick log in under 10 seconds: category, time, visit, note.
- Expenses with payer (me / parent / repaid), medical flag and receipt photo.
- Today: month totals for time, out of pocket and visits; recent entries.
- Monthly report: private link siblings open in a browser, notes private unless chosen; shows when each entry was logged.
- US medical-expense export (CSV + receipts ZIP) for the 2027 tax season.
- Data safety: every scenario in [data-safety.md](data-safety.md) passes.
- Light and dark themes, Dynamic Type, 44–56 pt touch targets.
- Free tier plus Pro ($9.99/month or $79/year, 7-day trial).

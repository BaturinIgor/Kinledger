# Data safety

A logged entry is never lost: not on a lost phone, an app update, a network failure or an accidental delete. No release ships unless all ten scenarios below pass.

## How it works

| Layer | What we do |
| --- | --- |
| Phone | Every entry is written to local SQLite first, before any network call. |
| Account | Sign in with Apple or Google in the first minutes; data belongs to the person, not the phone. |
| Backend | Our own sync server, not CloudKit, so the web report and a future Android app read the same data. |
| Sync | Background upload with retries; every entry has a client-generated id, so retries never duplicate. |
| Receipts | The photo stays on the phone until the server confirms the upload. |
| Trash | Delete moves an entry to trash for 30 days. |
| Edit history | Every edit keeps the previous version; the report shows when an entry changed. |
| Server | Daily backups and point-in-time restore for 30 days. |
| Updates | Numbered schema migrations; the local database is copied before each one. |
| Export | CSV and a ZIP of receipts at any time, on Free and after Pro ends. |
| Encryption | TLS in transit, encryption at rest, receipts served by short-lived links. |
| Indicator | "Saved to cloud: 2 minutes ago" on the Me tab; a warning when sync has failed for long. |

## Rules

- Never hard-delete a row while it is in trash.
- Ending a subscription never locks old entries or export.
- Every migration is tested on databases created by every earlier released version.

## Release-blocking scenarios

1. Offline: airplane mode, 20 entries and 5 receipts, network back on, everything reaches the cloud.
2. App killed mid-save: the entry is there after restart, with no duplicate.
3. New phone: sign in with the same account, all entries and receipts are there.
4. Lost phone: a second iPhone and the web show everything up to the last sync.
5. Accidental delete: the entry comes back from trash within 30 days.
6. Wrong edit: the previous version can be restored from history.
7. Upgrade from 1.0 to the current version on a 5,000-entry database loses nothing.
8. Bad network: a receipt upload fails three times, then arrives; the local copy is removed only after confirmation.
9. Conflict: the same entry edited on two offline phones keeps both versions and lets the person choose.
10. Leaving Pro: after cancelling, every entry is visible and exports to CSV and ZIP.

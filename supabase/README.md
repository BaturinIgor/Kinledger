# Kinledger cloud (Supabase)

The phone keeps everything in SQLite and works offline. This project holds a copy so a lost or
new phone gets everything back, and later serves the family report link.

## Deploying without a terminal

`.github/workflows/cloud-deploy.yml` does steps 2 and the account-deletion deploy below from the
GitHub Actions tab. Set the secrets listed at the top of that file, then run "Deploy cloud (Supabase)".

## One-time setup (about 5 minutes)

1. Create a free project at https://supabase.com (region close to the US, for example `us-east-1`).
2. SQL Editor → paste `migrations/20261118000000_cloud_backup.sql` → Run.
3. Authentication → Sign In / Providers → Apple → enable. For native iOS sign-in only the
   bundle id `app.kinledger` is needed under "Client IDs".
4. Settings → API: copy the Project URL and the `anon` public key into
   `Kinledger/Sync/CloudClient.swift` (`CloudConfig.projectURL` and `projectAnonKey`).
   The anon key is safe in the app: row-level security limits every table to its owner.
5. Sign in with Apple needs the paid Apple Developer account and the
   "Sign in with Apple" capability on the app id. Until then the app runs with backup off.

## Family report links

`migrations/20261118010000_report_links.sql` adds the links and `shared_report(token)`, the only
thing a browser without an account can call. The page is `docs/r/index.html` on GitHub Pages;
put the same project URL and anon key in `docs/r/config.js`.

## Account deletion (required by the App Store)

`functions/delete-account` revokes the person's Sign in with Apple tokens, removes their receipt
photos and deletes the user (all rows go with it). To deploy:

1. In the Apple Developer account: Keys → new key with "Sign in with Apple" → download the `.p8`.
2. `supabase secrets set APPLE_TEAM_ID=... APPLE_KEY_ID=... APPLE_CLIENT_ID=app.kinledger APPLE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"`
3. `supabase functions deploy delete-account`

## Rules the schema enforces

- Each person reads and writes only their own rows (row-level security on every table and the receipts bucket).
- The app cannot delete rows. Deleting an entry sets `deleted_at`.
- An older version never overwrites a newer one (`updated_at` check in the trigger).
- Every change keeps the replaced payload in `entry_versions`.
- Daily backups come with the Pro plan ($25/month) at launch; the free plan is enough for development.

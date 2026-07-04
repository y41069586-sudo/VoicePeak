# Backend module (optional, feature-flagged OFF)

The app is fully functional without a backend (`LocalOnlyBackend`). This module
adds **opt-in** account sync + community efficacy via Supabase.

**Hard invariant: face photos never leave the device.** Only numeric metrics and
routine are synced (`MetricsPayload` has no image field), and community data is
anonymized aggregates.

## Enable it

1. Create a Supabase project.
2. Run `schema.sql` in the SQL editor (tables, RLS, aggregate view, and the
   `delete_account()` RPC).
3. In the Supabase Auth settings, enable **Apple** as a provider and add your
   Services ID / key.
4. Provide the connection values to the app via Info.plist keys — populate them
   from a **git-ignored** `Secrets.xcconfig` (never commit keys):
   ```
   SUPABASE_URL = https://YOUR-PROJECT.supabase.co
   SUPABASE_ANON_KEY = YOUR_ANON_KEY
   ```
   and reference them in `Info.plist` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
5. Turn on `FeatureFlags.backendEnabled` (and `communityEnabled` for the
   aggregate feature). `AppState` will switch from `LocalOnlyBackend` to
   `SupabaseBackend` when the flag is on *and* config is present.

## What's synced

- `user_metrics` — a single owner-only JSONB row of numbers + routine.
- `efficacy_records` — anonymized opt-in "did the test pass" contributions.
- `community_efficacy` — a public aggregate view (only surfaced with ≥ 5 samples).

## Account deletion (App Store 5.1.1(v))

`deleteAccount()` calls the `delete_account()` RPC, which removes the user's rows
and their `auth.users` record. The in-app delete-all also wipes local data.

## Notes

- Session token is stored in `UserDefaults` as a template — move to the Keychain
  for production.
- Sign in with Apple is required by 4.8 when offering third-party auth; it's the
  only auth wired here.

# Deploying Vérité

Two independent things:

- **A. Ship the iOS app** via Codemagic → App Store Connect. (Required.)
- **B. Stand up the optional backend** (Supabase). Only if you flip
  `backendEnabled` on — the app is fully functional offline without it.

---

## A. Codemagic → App Store Connect

The `ios-release` workflow in `codemagic.yaml` builds a signed IPA and uploads it
to TestFlight. It runs when you push a **git tag** matching `v*` (e.g. `v1.0.0`).

### Why Codemagic asks for a Key ID / Issuer ID — it's not a YAML bug

Apple requires an **App Store Connect API key** to upload any build. It's a secret
tied to *your* Apple account, so it can never live in the repo and no code avoids
it. Having an Apple Developer login is **not** the same as having generated this
key. You create it once, paste it into a Codemagic variable group, and then it
"is there."

### What you must set up (one time)

1. **Create the app in App Store Connect** with bundle ID **`com.verite.app`**.

2. **Set up code signing in the Codemagic UI** (automatic signing):
   - Connect App Store Connect (Apple) and add your **distribution certificate** +
     **provisioning profile** for `com.verite.app` in Codemagic's code-signing
     settings. The workflow's `ios_signing` block + `xcode-project use-profiles`
     pick these up — **no signing secrets go in the repo or the variable group.**

3. **Add the 3 upload values to a Codemagic variable group named `Verite`**
   (App settings → **Environment variables** → *Group* = `Verite`, each **Secure**).
   These are used only to UPLOAD the build to TestFlight:

| Variable | Value | From |
|---|---|---|
| `APP_STORE_CONNECT_KEY` | the **whole `.p8` file contents** | App Store Connect → Users and Access → Integrations → App Store Connect API → Generate API Key (App Manager) |
| `APP_STORE_CONNECT_KEY_ID` | the Key ID | same page |
| `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID (a UUID) | same page (top) |

That's the complete list. Build number comes from `$BUILD_NUMBER` — nothing to set.

### Release it

```bash
git tag v1.0.0
git push origin v1.0.0
```

The build uploads to **TestFlight**. To push a public App Store release, set
`submit_to_app_store: true` (and a `release_type`) under `publishing.app_store_connect`.

### Before submitting: App Store metadata you'll need
- 6.9" screenshots (a generator lives in the session scratchpad, or make your own).
- Privacy "nutrition" labels: face photos = **not collected** (on-device only);
  if backend ON, "numeric metrics" are collected and linked to the account.
- The four legal docs in `legal/` (Impressum, Privacy, Terms, Disclaimer).

---

## B. Supabase backend (optional)

Only needed if you set `backendEnabled = true` in `FeatureFlags`. The app syncs
**numbers and routine only — never photos.**

### 1. Create a project & run the schema
- Create a Supabase project. Copy the **Project URL** and **anon key**
  (Project Settings → API).
- Open the **SQL Editor**, paste `Verite/Backend/schema.sql`, run it. That
  creates `user_metrics`, `efficacy_records`, the `community_efficacy` aggregate
  view, RLS policies, and the fallback `delete_account()` RPC.

### 2. Deploy the Edge Function (account deletion)
Apple requires in-app account deletion. The function lives in
`supabase/functions/delete-account/`.

```bash
# one time
supabase login
supabase link --project-ref <your-project-ref>

# deploy
supabase functions deploy delete-account
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected
into deployed functions automatically — **no secrets to set by hand.** The app
calls `functions/v1/delete-account` (see `SupabaseBackend.deleteAccount`).

> There are **no other Edge Functions to deploy.** Sign in with Apple, metric
> sync, and community efficacy all go through Supabase's built-in GoTrue +
> PostgREST — no custom functions required.

### 3. Configure Sign in with Apple (Supabase Auth)
- Supabase → **Authentication → Providers → Apple** → enable.
- Add your app's **Bundle ID** (`com.verite.app`) as an authorized client ID.
  (Native iOS uses the `id_token` flow; Supabase verifies the Apple token
  directly — no client secret needed for the native path.)
- In Xcode/`project.yml`, add the **Sign in with Apple** capability to the target
  before shipping the backend build.

### 4. Point the app at your project
`BackendConfig` reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from Info.plist.
Add these keys (empty = "not configured" = app stays offline-only):

```xml
<key>SUPABASE_URL</key>        <string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>   <string>$(SUPABASE_ANON_KEY)</string>
```

…and provide the build settings. Locally, add them to an `.xcconfig` (git-ignored).
In CI, create a Codemagic **environment variable group** named `verite_secrets`
with `SUPABASE_URL` / `SUPABASE_ANON_KEY` (mark them secure), and uncomment the
`groups: [verite_secrets]` line in the `ios-release` workflow.

### Optional: affiliate module
Same pattern with `AFFILIATE_ENDPOINT` / `AFFILIATE_TAG` (see
`Verite/Affiliate/README.md`). Point it at your own signing proxy — never ship
affiliate-network keys in the app.

---

## Recap: what to deploy where

| Thing | Where | Command / action |
|---|---|---|
| iOS app | App Store Connect | `git tag v1.0.0 && git push origin v1.0.0` |
| DB schema | Supabase SQL Editor | run `Verite/Backend/schema.sql` |
| `delete-account` fn | Supabase Edge Functions | `supabase functions deploy delete-account` |
| Apple auth | Supabase Auth → Apple | enable + add bundle id |
| Secrets (CI) | Codemagic env group `verite_secrets` | only if backend/affiliate ON |

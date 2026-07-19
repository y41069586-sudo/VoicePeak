// Glowé — `delete-account` Supabase Edge Function (Deno).
//
// Apple guideline 5.1.1(v): an account-based app must let users delete their
// account from inside the app. This function verifies the caller's JWT, then
// uses the service-role key to delete their auth user. The on-delete-cascade FK
// on `public.user_metrics` (see schema.sql) wipes their numeric rows with it.
//
// No face photos are ever stored server-side, so there is nothing else to erase.
//
// Deploy:
//   supabase functions deploy delete-account
//
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are
// injected automatically for deployed functions — you do NOT set them by hand.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
  if (!jwt) return json({ error: "missing_token" }, 401);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // 1) Identify the caller from their own token (never trust a client-sent id).
  const asUser = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: { user }, error: userErr } = await asUser.auth.getUser();
  if (userErr || !user) return json({ error: "invalid_token" }, 401);

  // 2) Delete as admin. The FK cascade removes public.user_metrics for this user.
  const admin = createClient(url, serviceKey);
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) return json({ error: delErr.message }, 500);

  return json({ ok: true });
});

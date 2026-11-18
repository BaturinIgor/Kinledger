// Deletes the signed-in person's cloud account: revokes their Sign in with Apple tokens (App Store
// guideline 5.1.1(v)), removes their receipt photos, then deletes the user, which removes every
// table row through `on delete cascade`. Entries on the phone are not touched.
//
// Secrets (supabase secrets set ...):
//   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (the .p8 contents), APPLE_CLIENT_ID (app.kinledger)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

async function appleClientSecret(): Promise<string> {
  const key = await importPKCS8(Deno.env.get("APPLE_PRIVATE_KEY")!, "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APPLE_KEY_ID")! })
    .setIssuer(Deno.env.get("APPLE_TEAM_ID")!)
    .setSubject(Deno.env.get("APPLE_CLIENT_ID")!)
    .setAudience("https://appleid.apple.com")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

async function revokeApple(authorizationCode: string): Promise<void> {
  const clientId = Deno.env.get("APPLE_CLIENT_ID")!;
  const secret = await appleClientSecret();
  const tokenResponse = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: secret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenResponse.ok) throw new Error(`Apple token exchange failed: ${tokenResponse.status}`);
  const { refresh_token } = await tokenResponse.json();
  const revokeResponse = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: secret,
      token: refresh_token,
      token_type_hint: "refresh_token",
    }),
  });
  if (!revokeResponse.ok) throw new Error(`Apple revoke failed: ${revokeResponse.status}`);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data.user) return json({ error: "Sign in again to delete the account." }, 401);
  const userId = data.user.id;

  const { authorization_code } = await req.json().catch(() => ({}));
  if (typeof authorization_code !== "string" || authorization_code.length === 0) {
    return json({ error: "Missing Apple authorization code." }, 400);
  }

  try {
    await revokeApple(authorization_code);
  } catch (e) {
    return json({ error: `Could not reach Apple: ${(e as Error).message}` }, 502);
  }

  // Receipt photos first: storage objects do not cascade with the user.
  const bucket = admin.storage.from("receipts");
  while (true) {
    const { data: files, error: listError } = await bucket.list(userId, { limit: 1000 });
    if (listError) return json({ error: listError.message }, 500);
    if (!files || files.length === 0) break;
    const { error: removeError } = await bucket.remove(files.map((f) => `${userId}/${f.name}`));
    if (removeError) return json({ error: removeError.message }, 500);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) return json({ error: deleteError.message }, 500);

  return json({ deleted: true });
});

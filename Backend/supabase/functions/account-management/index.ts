import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  },
});

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: "server_not_configured" }, 503);
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.toLowerCase().startsWith("bearer ") ? authHeader.slice(7).trim() : "";
  if (!token) return json({ error: "missing_authorization" }, 401);

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "invalid_session" }, 401);

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  let payload: { action?: string } = {};
  try { payload = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  const action = payload.action ?? "status";

  const getRequest = async () => {
    const { data, error } = await admin
      .from("account_deletion_requests")
      .select("requested_at,restore_until")
      .eq("user_id", user.id)
      .maybeSingle();
    if (error) throw error;
    return data as { requested_at: string; restore_until: string } | null;
  };

  try {
    if (action === "status") {
      const pending = await getRequest();
      if (!pending) return json({ pending: false });
      const restoreUntil = new Date(pending.restore_until);
      if (restoreUntil.getTime() <= Date.now()) {
        await admin.auth.admin.deleteUser(user.id, false);
        return json({ pending: false, deleted: true, restore_expired: true }, 410);
      }
      return json({ pending: true, requested_at: pending.requested_at, restore_until: pending.restore_until });
    }

    if (action === "request_delete") {
      const now = new Date();
      const restoreUntil = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      const { error } = await admin.from("account_deletion_requests").upsert({
        user_id: user.id,
        requested_at: now.toISOString(),
        restore_until: restoreUntil.toISOString(),
        updated_at: now.toISOString(),
      }, { onConflict: "user_id" });
      if (error) throw error;
      return json({ pending: true, requested_at: now.toISOString(), restore_until: restoreUntil.toISOString() });
    }

    if (action === "restore") {
      const pending = await getRequest();
      if (!pending) return json({ restored: true, pending: false });
      if (new Date(pending.restore_until).getTime() <= Date.now()) {
        await admin.auth.admin.deleteUser(user.id, false);
        return json({ restored: false, deleted: true, restore_expired: true }, 410);
      }
      const { error } = await admin.from("account_deletion_requests").delete().eq("user_id", user.id);
      if (error) throw error;
      return json({ restored: true, pending: false });
    }

    return json({ error: "unknown_action" }, 400);
  } catch (error) {
    console.error("account-management", action, error);
    return json({ error: "account_operation_failed" }, 500);
  }
});

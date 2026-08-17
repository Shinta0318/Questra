import { createClient } from "npm:@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/http.ts";

type DeletionRequest = {
  id: string;
  owner_id: string;
  attempt_count: number;
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, { status: 405 });
  }
  const expected = Deno.env.get("DATA_RIGHTS_WORKER_SECRET") ?? "";
  const supplied = req.headers.get("x-worker-secret") ?? "";
  if (!expected || !constantTimeEqual(expected, supplied)) {
    return jsonResponse({ error: "Unauthorized" }, { status: 401 });
  }

  const client = adminClient();
  const { data, error } = await client.rpc("claim_scheduled_account_deletions", {
    p_limit: 20,
  });
  if (error) return jsonResponse({ error: "Worker claim failed" }, { status: 500 });

  const requests = (data ?? []) as DeletionRequest[];
  const results = [];
  for (const request of requests) {
    try {
      const { error: deletionError } = await client.auth.admin.deleteUser(
        request.owner_id,
        true,
      );
      if (deletionError) throw deletionError;
      await client.rpc("resolve_account_deletion_worker", {
        p_request_id: request.id,
        p_completed: true,
        p_error: null,
      });
      results.push({ request_id: request.id, status: "completed" });
    } catch (error) {
      await client.rpc("resolve_account_deletion_worker", {
        p_request_id: request.id,
        p_completed: false,
        p_error: String(error),
      });
      results.push({ request_id: request.id, status: "retry_scheduled" });
    }
  }
  return jsonResponse({ claimed: requests.length, results });
});

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Supabase worker configuration missing");
  return createClient(url, key, { auth: { persistSession: false } });
}

function constantTimeEqual(left: string, right: string) {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  let difference = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index++) {
    difference |= (a[index % a.length] ?? 0) ^ (b[index % b.length] ?? 0);
  }
  return difference === 0;
}

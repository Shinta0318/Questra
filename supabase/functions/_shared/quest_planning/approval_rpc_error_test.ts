import { approvalRpcFailure } from "./approval_rpc_error.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("known approval conflicts do not look like successful saves", () => {
  assertEquals(approvalRpcFailure({ message: "route_changed_since_preview" }), {
    error: "route_changed_since_preview",
    status: 409,
    state: "conflict",
  });
  assertEquals(
    approvalRpcFailure({
      message: "preview_already_approved_with_different_selection",
    }),
    {
      error: "preview_already_approved_with_different_selection",
      status: 409,
      state: "conflict",
    },
  );
});

Deno.test("unknown and malformed RPC failures stay retryable without raw DB details", () => {
  const expected = {
    error: "approval_failed",
    status: 503,
    state: "retryable_error",
  };
  assertEquals(
    approvalRpcFailure({ message: "connection terminated by administrator" }),
    expected,
  );
  assertEquals(approvalRpcFailure("not JSON"), expected);
});

Deno.test("database consent denial remains a 403 without leaking SQL details", () => {
  assertEquals(approvalRpcFailure({ message: "ai_legal_consent_required" }), {
    error: "consent_required",
    status: 403,
    state: "consent_required",
  });
});

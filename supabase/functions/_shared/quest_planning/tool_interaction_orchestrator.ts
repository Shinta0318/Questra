import type {
  ProviderRequest,
  ProviderResponse,
  ProviderToolCall,
} from "./contracts.ts";
import { callGeminiInteraction } from "./interactions_adapter.ts";
import { QUESTRA_TOOLS } from "./tool_registry.ts";
import {
  executeQuestraTool,
  type ToolExecutionContext,
  type ToolExecutionResult,
} from "./tool_server.ts";

type ProviderCaller = (request: ProviderRequest) => Promise<ProviderResponse>;
type ToolExecutor = (
  name: string,
  args: Record<string, unknown>,
  context: ToolExecutionContext,
) => Promise<ToolExecutionResult>;

export type ToolInteractionOptions = {
  maxTurns?: number;
  maxToolCalls?: number;
  overallTimeoutMs?: number;
};

export type ToolInteractionDependencies = {
  callProvider?: ProviderCaller;
  executeTool?: ToolExecutor;
  now?: () => number;
};

export async function callGeminiInteractionWithTools(
  request: ProviderRequest,
  context: { userId: string; approved?: boolean },
  options: ToolInteractionOptions = {},
  dependencies: ToolInteractionDependencies = {},
): Promise<ProviderResponse> {
  const callProvider = dependencies.callProvider ?? callGeminiInteraction;
  const executeTool = dependencies.executeTool ?? executeQuestraTool;
  const now = dependencies.now ?? Date.now;
  const maxTurns = bounded(options.maxTurns, 3, 1, 5);
  const maxToolCalls = bounded(options.maxToolCalls, 8, 1, 12);
  const deadline = now() + bounded(options.overallTimeoutMs, 120_000, 5_000, 180_000);
  const history: unknown[] = [userInputStep(request.input)];
  const seenCalls = new Set<string>();
  let totalToolCalls = 0;
  let response = await callTurn(request, history, 0, deadline, now, callProvider);
  let usage = response.usage;
  let latencyMs = response.latencyMs;
  let groundingMetadata = response.groundingMetadata;

  for (let turn = 1; response.toolCalls.length > 0; turn++) {
    if (response.finishReason !== "requires_action") {
      return toolFailure(response, "Provider returned a tool call without requires_action");
    }
    if (turn > maxTurns || !response.continuation?.steps.length) {
      return toolFailure(response, "Tool continuation limit or state was invalid");
    }
    totalToolCalls += response.toolCalls.length;
    if (totalToolCalls > maxToolCalls) {
      return toolFailure(response, "Tool call limit exceeded");
    }

    const results: unknown[] = [];
    for (const call of response.toolCalls) {
      const definition = QUESTRA_TOOLS[call.name];
      if (!definition || definition.access !== "read") {
        return toolFailure(
          response,
          "A write or unknown tool requires an explicit user approval flow",
        );
      }
      const fingerprint = toolFingerprint(call);
      if (seenCalls.has(fingerprint)) {
        return toolFailure(response, "Repeated tool call cycle detected");
      }
      seenCalls.add(fingerprint);
      const result = await executeTool(call.name, call.arguments, {
        userId: context.userId,
        traceId: request.traceId,
        approved: context.approved === true,
      });
      if (!result.ok) {
        return toolFailure(response, `Tool execution failed: ${result.error ?? "unknown"}`);
      }
      results.push(functionResult(call, result.data));
    }

    history.push(...response.continuation.steps, ...results);
    response = await callTurn(
      request,
      history,
      turn,
      deadline,
      now,
      callProvider,
    );
    usage = mergeUsage(usage, response.usage);
    latencyMs += response.latencyMs;
    groundingMetadata = mergeGrounding(
      groundingMetadata,
      response.groundingMetadata,
    );
  }
  return {
    ...response,
    continuation: undefined,
    usage,
    latencyMs,
    groundingMetadata,
  };
}

async function callTurn(
  request: ProviderRequest,
  history: unknown[],
  turn: number,
  deadline: number,
  now: () => number,
  callProvider: ProviderCaller,
) {
  const remaining = deadline - now();
  if (remaining < 500) {
    return requestFailure(request, "Tool interaction timed out");
  }
  return callProvider({
    ...request,
    interactionHistory: [...history],
    timeoutMs: Math.min(request.timeoutMs ?? 45_000, remaining),
    idempotencyKey: turn === 0
      ? request.idempotencyKey
      : `${request.idempotencyKey}:tool-turn-${turn}`,
  });
}

function userInputStep(value: unknown) {
  return {
    type: "user_input",
    content: [{ type: "text", text: boundedJson(value, 40_000) }],
  };
}

function functionResult(call: ProviderToolCall, data: unknown) {
  return {
    type: "function_result",
    call_id: call.id,
    name: call.name,
    result: [{ type: "text", text: boundedJson(data, 12_000) }],
  };
}

function toolFingerprint(call: ProviderToolCall) {
  return `${call.name}:${stableJson(call.arguments)}`;
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (!value || typeof value !== "object") return JSON.stringify(value) ?? "null";
  return `{${Object.keys(value as Record<string, unknown>).sort().map((key) =>
    `${JSON.stringify(key)}:${stableJson((value as Record<string, unknown>)[key])}`
  ).join(",")}}`;
}

function mergeUsage(
  first: ProviderResponse["usage"],
  second: ProviderResponse["usage"],
) {
  const result: ProviderResponse["usage"] = {};
  for (const key of [
    "inputTokens",
    "outputTokens",
    "totalTokens",
    "generatedOutputTokens",
    "thoughtTokens",
    "cachedTokens",
    "toolUseTokens",
  ] as const) {
    const values = [first[key], second[key]].filter(
      (value): value is number => value !== undefined,
    );
    if (values.length > 0) result[key] = values.reduce((sum, value) => sum + value, 0);
  }
  return result;
}

function mergeGrounding(
  first: Record<string, unknown> | null,
  second: Record<string, unknown> | null,
) {
  if (!first) return second;
  if (!second) return first;
  return {
    steps: uniqueObjects(first.steps, second.steps),
    queries: uniqueStrings(first.queries, second.queries),
    sources: uniqueSources(first.sources, second.sources),
    retrievedAt: typeof second.retrievedAt === "string"
      ? second.retrievedAt
      : first.retrievedAt,
  };
}

function uniqueObjects(first: unknown, second: unknown) {
  const values = [...asArray(first), ...asArray(second)];
  const seen = new Set<string>();
  return values.filter((value) => {
    const key = stableJson(value);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function uniqueStrings(first: unknown, second: unknown) {
  return [...new Set([...asArray(first), ...asArray(second)].filter(
    (value): value is string => typeof value === "string",
  ))];
}

function uniqueSources(first: unknown, second: unknown) {
  const sources = uniqueObjects(first, second);
  const byUri = new Map<string, unknown>();
  for (const source of sources) {
    if (!source || typeof source !== "object") continue;
    const uri = (source as Record<string, unknown>).uri;
    if (typeof uri === "string" && !byUri.has(uri)) byUri.set(uri, source);
  }
  return [...byUri.values()];
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function boundedJson(value: unknown, limit: number) {
  const serialized = JSON.stringify(value) ?? "null";
  if (serialized.length <= limit) return serialized;
  return JSON.stringify({ truncated: true, preview: serialized.slice(0, limit - 40) });
}

function toolFailure(response: ProviderResponse, message: string): ProviderResponse {
  return {
    ...response,
    output: null,
    text: "",
    toolCalls: [],
    continuation: undefined,
    finishReason: "error",
    error: { code: "tool_failed", retryable: false, message },
  };
}

function requestFailure(request: ProviderRequest, message: string): ProviderResponse {
  return {
    provider: "gemini",
    model: "unresolved",
    modelVersion: "unresolved",
    thinkingLevel: request.thinkingLevel ?? "low",
    output: null,
    text: "",
    toolCalls: [],
    groundingMetadata: null,
    usage: {},
    latencyMs: 0,
    finishReason: "error",
    traceId: request.traceId,
    error: { code: "timeout", retryable: true, message },
  };
}

function bounded(value: number | undefined, fallback: number, min: number, max: number) {
  return Number.isFinite(value)
    ? Math.min(max, Math.max(min, Math.round(value!)))
    : fallback;
}

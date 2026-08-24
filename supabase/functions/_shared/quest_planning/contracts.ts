export type AiProviderName = "gemini" | "openai";

export type ModelRole =
  | "lightweight_classifier"
  | "quest_understanding"
  | "quest_proposal"
  | "strategic_planner"
  | "mission_generator"
  | "mission_critic"
  | "targeted_repair"
  | "schema_repair";

export type ThinkingLevel = "minimal" | "low" | "medium" | "high";

export type ProviderTool = {
  type: "google_search" | "function";
  name?: string;
  description?: string;
  parameters?: Record<string, unknown>;
};

export type ProviderRequest = {
  operation: string;
  modelRole: ModelRole;
  promptVersion: string;
  schemaVersion: string;
  systemInstruction: string;
  input: unknown;
  responseSchema?: Record<string, unknown>;
  tools?: ProviderTool[];
  thinkingLevel?: ThinkingLevel;
  timeoutMs?: number;
  maxOutputTokens?: number;
  temperature?: number;
  idempotencyKey: string;
  traceId: string;
  userId?: string | null;
  // SHA-256 of a short-lived network abuse key. Never pass or persist a raw IP.
  abuseKeyHash?: string | null;
};

export type ProviderToolCall = {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
};

export type ProviderUsage = {
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
};

export type ProviderResponse = {
  provider: AiProviderName;
  model: string;
  modelVersion: string;
  output: unknown;
  text: string;
  toolCalls: ProviderToolCall[];
  groundingMetadata: Record<string, unknown> | null;
  usage: ProviderUsage;
  latencyMs: number;
  finishReason: string;
  traceId: string;
  error: ProviderError | null;
};

export type ProviderErrorCode =
  | "timeout"
  | "rate_limited"
  | "unavailable"
  | "malformed_output"
  | "schema_invalid"
  | "semantic_invalid"
  | "safety_blocked"
  | "grounding_failed"
  | "tool_failed"
  | "context_too_large"
  | "cancelled"
  | "budget_exhausted"
  | "budget_unavailable"
  | "ai_disabled"
  | "unknown";

export type ProviderError = {
  code: ProviderErrorCode;
  retryable: boolean;
  status?: number;
  message: string;
};

export type ValidationIssue = {
  path: string;
  code: string;
  message: string;
  missionClientId?: string;
};

export type ValidationResult = {
  valid: boolean;
  issues: ValidationIssue[];
};

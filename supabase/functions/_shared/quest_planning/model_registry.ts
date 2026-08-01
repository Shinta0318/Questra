import { ModelRole, ThinkingLevel } from "./contracts.ts";

export type ModelReleaseType = "stable" | "preview" | "latest" | "experimental";

export type ModelDefinition = {
  name: string;
  family: string;
  releaseType: ModelReleaseType;
  enabled: boolean;
  supportsInteractions: boolean;
  supportsStructuredOutput: boolean;
  supportsGoogleSearch: boolean;
  supportsFunctionCalling: boolean;
  supportedThinkingLevels: ThinkingLevel[];
  defaultThinkingLevel: ThinkingLevel;
};

export type ModelRoute = { primary: string; fallback: string; preview?: string };

// Production routes use explicit Stable model names. Latest and experimental
// aliases are intentionally absent so a provider-side swap cannot reach users.
export const GEMINI_MODELS: Record<string, ModelDefinition> = {
  "gemini-3.6-flash": {
    name: "gemini-3.6-flash",
    family: "gemini-3.6-flash",
    releaseType: "stable",
    enabled: true,
    supportsInteractions: true,
    supportsStructuredOutput: true,
    supportsGoogleSearch: true,
    supportsFunctionCalling: true,
    supportedThinkingLevels: ["low", "medium", "high"],
    defaultThinkingLevel: "medium",
  },
  "gemini-3.5-flash": {
    name: "gemini-3.5-flash",
    family: "gemini-3.5-flash",
    releaseType: "stable",
    enabled: true,
    supportsInteractions: true,
    supportsStructuredOutput: true,
    supportsGoogleSearch: true,
    supportsFunctionCalling: true,
    supportedThinkingLevels: ["low", "medium", "high"],
    defaultThinkingLevel: "medium",
  },
  "gemini-3.5-flash-lite": {
    name: "gemini-3.5-flash-lite",
    family: "gemini-3.5-flash-lite",
    releaseType: "stable",
    enabled: true,
    supportsInteractions: true,
    supportsStructuredOutput: true,
    supportsGoogleSearch: false,
    supportsFunctionCalling: true,
    supportedThinkingLevels: ["minimal", "low", "medium", "high"],
    defaultThinkingLevel: "low",
  },
  "gemini-3.1-pro-preview": {
    name: "gemini-3.1-pro-preview",
    family: "gemini-3.1-pro",
    releaseType: "preview",
    enabled: false,
    supportsInteractions: true,
    supportsStructuredOutput: true,
    supportsGoogleSearch: true,
    supportsFunctionCalling: true,
    supportedThinkingLevels: ["low", "medium", "high"],
    defaultThinkingLevel: "high",
  },
};

const ROUTES: Record<ModelRole, ModelRoute> = {
  lightweight_classifier: { primary: "gemini-3.5-flash-lite", fallback: "gemini-3.5-flash" },
  quest_understanding: { primary: "gemini-3.5-flash", fallback: "gemini-3.5-flash-lite" },
  quest_proposal: { primary: "gemini-3.5-flash", fallback: "gemini-3.6-flash", preview: "gemini-3.1-pro-preview" },
  strategic_planner: { primary: "gemini-3.6-flash", fallback: "gemini-3.5-flash", preview: "gemini-3.1-pro-preview" },
  mission_generator: { primary: "gemini-3.6-flash", fallback: "gemini-3.5-flash", preview: "gemini-3.1-pro-preview" },
  mission_critic: { primary: "gemini-3.6-flash", fallback: "gemini-3.5-flash", preview: "gemini-3.1-pro-preview" },
  targeted_repair: { primary: "gemini-3.5-flash", fallback: "gemini-3.5-flash-lite" },
  schema_repair: { primary: "gemini-3.5-flash-lite", fallback: "gemini-3.5-flash" },
};

export function resolveModel(role: ModelRole, options: { fallback?: boolean; allowPreview?: boolean } = {}) {
  const route = ROUTES[role];
  const configured = Deno.env.get(`GEMINI_MODEL_${role.toUpperCase()}`);
  const candidate = configured || (options.allowPreview && route.preview) ||
    (options.fallback ? route.fallback : route.primary);
  const definition = GEMINI_MODELS[candidate];
  if (!definition) return GEMINI_MODELS[route.primary];
  if (definition.releaseType === "preview" && !options.allowPreview) return GEMINI_MODELS[route.primary];
  if (definition.releaseType === "latest" || definition.releaseType === "experimental") return GEMINI_MODELS[route.primary];
  if (!definition.enabled && definition.releaseType !== "preview") return GEMINI_MODELS[route.fallback];
  return definition;
}

export function modelSupportsThinking(model: ModelDefinition, level: ThinkingLevel) {
  return model.supportedThinkingLevels.includes(level);
}

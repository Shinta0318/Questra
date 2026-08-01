export const SCHEMA_VERSION = "quest-hierarchy-3.0";

const nonEmptyString = (minLength: number, maxLength: number) => ({
  type: "string",
  minLength,
  maxLength,
});

export const questUnderstandingSchema = {
  type: "object",
  additionalProperties: false,
  required: ["originalWish", "desiredOutcome", "motivation", "currentState", "constraints", "unknowns", "risks", "assumptions", "clarificationRequired", "clarificationQuestions"],
  properties: {
    originalWish: nonEmptyString(1, 1200),
    desiredOutcome: nonEmptyString(3, 500),
    motivation: nonEmptyString(1, 500),
    currentState: nonEmptyString(1, 500),
    targetDate: { type: ["string", "null"] },
    budget: { type: ["string", "null"] },
    availableTime: { type: ["string", "null"] },
    experience: { type: ["string", "null"] },
    location: { type: ["string", "null"] },
    partyType: { type: ["string", "null"] },
    constraints: { type: "array", maxItems: 12, items: nonEmptyString(1, 200) },
    unknowns: { type: "array", maxItems: 8, items: nonEmptyString(1, 200) },
    risks: { type: "array", maxItems: 8, items: nonEmptyString(1, 200) },
    assumptions: { type: "array", maxItems: 8, items: nonEmptyString(1, 200) },
    clarificationRequired: { type: "boolean" },
    clarificationQuestions: { type: "array", maxItems: 3, items: nonEmptyString(3, 200) },
  },
} as Record<string, unknown>;

export const successContractSchema = {
  type: "object",
  additionalProperties: false,
  required: ["questOutcome", "successEvidence", "completionVerification", "constraints", "assumptions"],
  properties: {
    questOutcome: nonEmptyString(3, 500),
    successEvidence: { type: "array", minItems: 1, maxItems: 8, items: nonEmptyString(3, 300) },
    completionVerification: nonEmptyString(3, 500),
    targetDate: { type: ["string", "null"] },
    constraints: { type: "array", maxItems: 12, items: nonEmptyString(1, 200) },
    assumptions: { type: "array", maxItems: 8, items: nonEmptyString(1, 200) },
  },
} as Record<string, unknown>;

export const strategicPlanSchema = {
  type: "object",
  additionalProperties: false,
  required: ["phases", "milestones", "criticalPath", "risks", "reviewPoints"],
  properties: {
    phases: { type: "array", minItems: 1, maxItems: 10, items: nonEmptyString(3, 200) },
    milestones: { type: "array", minItems: 1, maxItems: 20, items: nonEmptyString(3, 300) },
    criticalPath: { type: "array", minItems: 1, maxItems: 20, items: nonEmptyString(3, 200) },
    risks: { type: "array", maxItems: 12, items: nonEmptyString(3, 300) },
    optionalPaths: { type: "array", maxItems: 8, items: nonEmptyString(3, 300) },
    reviewPoints: { type: "array", minItems: 1, maxItems: 12, items: nonEmptyString(3, 300) },
  },
} as Record<string, unknown>;

export const missionPlanSchema = {
  type: "object",
  additionalProperties: false,
  required: ["planVersion", "questId", "missions"],
  properties: {
    planVersion: { type: "integer", minimum: 1 },
    questId: nonEmptyString(1, 100),
    missions: {
      type: "array",
      minItems: 1,
      maxItems: 30,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["clientId", "title", "action", "purpose", "doneCondition", "expectedOutput", "estimatedEffortMinutes", "calendarDurationDays", "dependencies", "required", "confidence"],
        properties: {
          clientId: nonEmptyString(1, 80),
          title: nonEmptyString(3, 100),
          action: nonEmptyString(10, 500),
          purpose: nonEmptyString(5, 300),
          doneCondition: nonEmptyString(10, 500),
          expectedOutput: nonEmptyString(3, 300),
          estimatedEffortMinutes: { type: "integer", minimum: 1, maximum: 1440 },
          calendarDurationDays: { type: "integer", minimum: 0, maximum: 3650 },
          dependencies: { type: "array", maxItems: 20, items: nonEmptyString(1, 80) },
          required: { type: "boolean" },
          confidence: { type: "number", minimum: 0, maximum: 1 },
        },
      },
    },
  },
} as Record<string, unknown>;

export const routeMissionPlanSchema = {
  type: "object",
  additionalProperties: false,
  required: ["planVersion", "questId", "missions"],
  properties: {
    planVersion: { type: "integer", minimum: 1 },
    questId: nonEmptyString(1, 100),
    missions: {
      type: "array", minItems: 1, maxItems: 20,
      items: {
        type: "object", additionalProperties: false,
        required: ["clientId", "title", "objective", "successCondition", "expectedOutcome", "calendarDurationDays", "dependencies", "required", "weight", "confidence"],
        properties: {
          clientId: nonEmptyString(1, 80),
          title: nonEmptyString(3, 100),
          objective: nonEmptyString(10, 500),
          successCondition: nonEmptyString(10, 500),
          expectedOutcome: nonEmptyString(3, 300),
          calendarDurationDays: { type: "integer", minimum: 0, maximum: 3650 },
          dependencies: { type: "array", maxItems: 20, items: nonEmptyString(1, 80) },
          required: { type: "boolean" },
          weight: { type: "number", exclusiveMinimum: 0, maximum: 100 },
          confidence: { type: "number", minimum: 0, maximum: 1 },
        },
      },
    },
  },
} as Record<string, unknown>;

export const taskPlanSchema = {
  type: "object", additionalProperties: false,
  required: ["planVersion", "questId", "missionClientId", "tasks"],
  properties: {
    planVersion: { type: "integer", minimum: 1 },
    questId: nonEmptyString(1, 100),
    missionClientId: nonEmptyString(1, 80),
    tasks: {
      type: "array", minItems: 1, maxItems: 30,
      items: {
        type: "object", additionalProperties: false,
        required: ["clientId", "title", "action", "purpose", "doneCondition", "expectedOutput", "estimatedEffortMinutes", "dependencies", "required", "confidence"],
        properties: {
          clientId: nonEmptyString(1, 80), title: nonEmptyString(3, 100),
          action: nonEmptyString(10, 500), purpose: nonEmptyString(5, 300),
          doneCondition: nonEmptyString(10, 500), expectedOutput: nonEmptyString(3, 300),
          estimatedEffortMinutes: { type: "integer", minimum: 1, maximum: 1440 },
          dependencies: { type: "array", maxItems: 20, items: nonEmptyString(1, 80) },
          required: { type: "boolean" }, confidence: { type: "number", minimum: 0, maximum: 1 },
        },
      },
    },
  },
} as Record<string, unknown>;

export const missionCriticSchema = {
  type: "object",
  additionalProperties: false,
  required: ["passed", "missionResults", "overallScore"],
  properties: {
    passed: { type: "boolean" },
    overallScore: { type: "number", minimum: 0, maximum: 100 },
    missionResults: {
      type: "array",
      minItems: 1,
      maxItems: 30,
      items: {
        type: "object",
        required: ["clientId", "passed", "scores", "repairReasons"],
        properties: {
          clientId: nonEmptyString(1, 80),
          passed: { type: "boolean" },
          scores: { type: "object" },
          repairReasons: { type: "array", maxItems: 8, items: nonEmptyString(1, 200) },
        },
      },
    },
  },
} as Record<string, unknown>;

export const missionRepairSchema = {
  ...missionPlanSchema,
  description: "A plan containing every original good Mission unchanged and only failed Missions repaired.",
} as Record<string, unknown>;

export const routeMissionRepairSchema = {
  ...routeMissionPlanSchema,
  description: "Preserve passing outcome Missions exactly and repair only failed Missions.",
} as Record<string, unknown>;

export const taskRepairSchema = {
  ...taskPlanSchema,
  description: "Preserve passing Tasks exactly and repair only failed Tasks.",
} as Record<string, unknown>;

export const taskCriticSchema = {
  type: "object", additionalProperties: false,
  required: ["passed", "taskResults", "overallScore"],
  properties: {
    passed: { type: "boolean" }, overallScore: { type: "number", minimum: 0, maximum: 100 },
    taskResults: {
      type: "array", minItems: 1, maxItems: 30,
      items: {
        type: "object", additionalProperties: false,
        required: ["clientId", "passed", "repairReasons"],
        properties: {
          clientId: nonEmptyString(1, 80), passed: { type: "boolean" },
          repairReasons: { type: "array", maxItems: 8, items: nonEmptyString(1, 200) },
        },
      },
    },
  },
} as Record<string, unknown>;

export const questPlanningSchemas = {
  QuestUnderstanding: questUnderstandingSchema,
  SuccessContract: successContractSchema,
  StrategicPlan: strategicPlanSchema,
  MissionPlan: missionPlanSchema,
  MissionCriticResult: missionCriticSchema,
  MissionRepairResult: missionRepairSchema,
  RouteMissionPlan: routeMissionPlanSchema,
  RouteMissionRepairResult: routeMissionRepairSchema,
  TaskPlan: taskPlanSchema,
  TaskRepairResult: taskRepairSchema,
  TaskCriticResult: taskCriticSchema,
};

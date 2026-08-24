import { validateJsonSchema } from "./json_schema_validator.ts";

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

Deno.test("JSON schema validator accepts a complete bounded object", () => {
  const schema = {
    type: "object",
    additionalProperties: false,
    required: ["name", "items"],
    properties: {
      name: { type: "string", minLength: 3, maxLength: 10 },
      items: { type: "array", minItems: 1, maxItems: 2, items: { type: "integer", minimum: 1, maximum: 5 } },
    },
  } as Record<string, unknown>;
  assert(validateJsonSchema({ name: "Arc", items: [1, 5] }, schema).length === 0, "valid payload was rejected");
});

Deno.test("JSON schema validator rejects missing, extra and out-of-range values", () => {
  const schema = {
    type: "object",
    additionalProperties: false,
    required: ["name", "items"],
    properties: {
      name: { type: "string", minLength: 3 },
      items: { type: "array", maxItems: 1, items: { type: "integer", minimum: 1 } },
    },
  } as Record<string, unknown>;
  const issues = validateJsonSchema({ items: [0, 2], extra: true }, schema);
  const codes = new Set(issues.map((item) => item.code));
  assert(codes.has("required"), "missing required property was accepted");
  assert(codes.has("additional_property"), "extra property was accepted");
  assert(codes.has("max_items"), "oversized array was accepted");
  assert(codes.has("minimum"), "out-of-range number was accepted");
});

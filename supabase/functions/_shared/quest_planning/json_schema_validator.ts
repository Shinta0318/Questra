export type JsonSchemaIssue = {
  path: string;
  code: string;
  message: string;
};

export function validateJsonSchema(
  value: unknown,
  schema: Record<string, unknown>,
): JsonSchemaIssue[] {
  const issues: JsonSchemaIssue[] = [];
  visit(value, schema, "$", issues, 0);
  return issues;
}

function visit(
  value: unknown,
  schema: Record<string, unknown>,
  path: string,
  issues: JsonSchemaIssue[],
  depth: number,
) {
  if (depth > 40) {
    issues.push({ path, code: "schema_depth", message: "Schema nesting is too deep" });
    return;
  }
  const allowedTypes = Array.isArray(schema.type)
    ? schema.type.filter((item): item is string => typeof item === "string")
    : typeof schema.type === "string"
    ? [schema.type]
    : [];
  if (allowedTypes.length > 0 && !allowedTypes.some((type) => matchesType(value, type))) {
    issues.push({ path, code: "type", message: `Expected ${allowedTypes.join(" or ")}` });
    return;
  }
  if (Array.isArray(schema.enum) && !schema.enum.some((item) => Object.is(item, value))) {
    issues.push({ path, code: "enum", message: "Value is not in the allowed set" });
  }
  if (typeof value === "string") validateString(value, schema, path, issues);
  if (typeof value === "number") validateNumber(value, schema, path, issues);
  if (Array.isArray(value)) validateArray(value, schema, path, issues, depth);
  if (isRecord(value)) validateObject(value, schema, path, issues, depth);
}

function validateString(
  value: string,
  schema: Record<string, unknown>,
  path: string,
  issues: JsonSchemaIssue[],
) {
  const length = [...value].length;
  if (typeof schema.minLength === "number" && length < schema.minLength) {
    issues.push({ path, code: "min_length", message: `Must contain at least ${schema.minLength} characters` });
  }
  if (typeof schema.maxLength === "number" && length > schema.maxLength) {
    issues.push({ path, code: "max_length", message: `Must contain at most ${schema.maxLength} characters` });
  }
  if (typeof schema.pattern === "string") {
    try {
      if (!new RegExp(schema.pattern).test(value)) issues.push({ path, code: "pattern", message: "Value does not match the required pattern" });
    } catch (_) {
      issues.push({ path, code: "invalid_schema_pattern", message: "Schema pattern is invalid" });
    }
  }
}

function validateNumber(
  value: number,
  schema: Record<string, unknown>,
  path: string,
  issues: JsonSchemaIssue[],
) {
  if (!Number.isFinite(value)) issues.push({ path, code: "finite", message: "Number must be finite" });
  if (schema.type === "integer" && !Number.isInteger(value)) issues.push({ path, code: "integer", message: "Expected an integer" });
  if (typeof schema.minimum === "number" && value < schema.minimum) issues.push({ path, code: "minimum", message: `Must be at least ${schema.minimum}` });
  if (typeof schema.maximum === "number" && value > schema.maximum) issues.push({ path, code: "maximum", message: `Must be at most ${schema.maximum}` });
  if (typeof schema.exclusiveMinimum === "number" && value <= schema.exclusiveMinimum) issues.push({ path, code: "exclusive_minimum", message: `Must be greater than ${schema.exclusiveMinimum}` });
  if (typeof schema.exclusiveMaximum === "number" && value >= schema.exclusiveMaximum) issues.push({ path, code: "exclusive_maximum", message: `Must be less than ${schema.exclusiveMaximum}` });
}

function validateArray(
  value: unknown[],
  schema: Record<string, unknown>,
  path: string,
  issues: JsonSchemaIssue[],
  depth: number,
) {
  if (typeof schema.minItems === "number" && value.length < schema.minItems) issues.push({ path, code: "min_items", message: `Must contain at least ${schema.minItems} items` });
  if (typeof schema.maxItems === "number" && value.length > schema.maxItems) issues.push({ path, code: "max_items", message: `Must contain at most ${schema.maxItems} items` });
  if (schema.uniqueItems === true && new Set(value.map((item) => JSON.stringify(item))).size !== value.length) issues.push({ path, code: "unique_items", message: "Items must be unique" });
  if (isRecord(schema.items)) value.forEach((item, index) => visit(item, schema.items as Record<string, unknown>, `${path}[${index}]`, issues, depth + 1));
}

function validateObject(
  value: Record<string, unknown>,
  schema: Record<string, unknown>,
  path: string,
  issues: JsonSchemaIssue[],
  depth: number,
) {
  const properties = isRecord(schema.properties) ? schema.properties : {};
  const required = Array.isArray(schema.required)
    ? schema.required.filter((item): item is string => typeof item === "string")
    : [];
  for (const key of required) {
    if (!Object.prototype.hasOwnProperty.call(value, key)) issues.push({ path: `${path}.${key}`, code: "required", message: "Required property is missing" });
  }
  if (schema.additionalProperties === false) {
    for (const key of Object.keys(value)) {
      if (!Object.prototype.hasOwnProperty.call(properties, key)) issues.push({ path: `${path}.${key}`, code: "additional_property", message: "Unexpected property" });
    }
  }
  for (const [key, propertySchema] of Object.entries(properties)) {
    if (Object.prototype.hasOwnProperty.call(value, key) && isRecord(propertySchema)) visit(value[key], propertySchema, `${path}.${key}`, issues, depth + 1);
  }
}

function matchesType(value: unknown, type: string) {
  switch (type) {
    case "null": return value === null;
    case "object": return isRecord(value);
    case "array": return Array.isArray(value);
    case "string": return typeof value === "string";
    case "number": return typeof value === "number" && Number.isFinite(value);
    case "integer": return typeof value === "number" && Number.isInteger(value);
    case "boolean": return typeof value === "boolean";
    default: return false;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

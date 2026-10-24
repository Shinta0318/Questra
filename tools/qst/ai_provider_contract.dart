const aiProviderEntryPath = 'supabase/functions/_shared/ai_provider.ts';
const interactionsAdapterPath =
    'supabase/functions/_shared/quest_planning/interactions_adapter.ts';
const modelRegistryPath =
    'supabase/functions/_shared/quest_planning/model_registry.ts';
const aiBudgetPath =
    'supabase/functions/_shared/quest_planning/ai_budget_admission.ts';

List<String> verifyStatelessAiPath({
  required String entry,
  required String adapter,
}) {
  final issues = <String>[];
  _require(
    entry,
    './quest_planning/interactions_adapter.ts',
    aiProviderEntryPath,
    issues,
  );
  _require(entry, 'callGeminiInteraction({', aiProviderEntryPath, issues);
  _require(adapter, 'store: false', interactionsAdapterPath, issues);
  _require(adapter, 'callGeminiInteraction(', interactionsAdapterPath, issues);
  return issues;
}

List<String> verifyAiBootstrapContract({
  required String entry,
  required String adapter,
  required String registry,
  required String budget,
}) {
  final issues = verifyStatelessAiPath(entry: entry, adapter: adapter);
  for (final snippet in [
    'https://generativelanguage.googleapis.com/v1/interactions',
    'GEMINI_API_KEY',
    'generation_config:',
    'max_output_tokens:',
    'thinking_level: thinkingLevel',
    'AbortController()',
    'reserveAiBudget(',
    'settleAiBudget(',
    'releaseAiBudget(',
    'AI_ALLOW_PREVIEW_MODELS',
  ]) {
    _require(adapter, snippet, interactionsAdapterPath, issues);
  }
  for (final snippet in [
    'releaseType: "stable"',
    'resolveModel(',
    'resolveFallbackModel(',
    'if (definition.releaseType === "preview" && !allowPreview)',
    'if (definition.releaseType === "latest" || definition.releaseType === "experimental")',
  ]) {
    _require(registry, snippet, modelRegistryPath, issues);
  }
  for (final snippet in [
    'reserve_ai_usage_budget_v2',
    'release_ai_usage_budget',
    'settleAiBudget(',
  ]) {
    _require(budget, snippet, aiBudgetPath, issues);
  }
  _require(
    entry,
    'Direct OpenAI generation is disabled',
    aiProviderEntryPath,
    issues,
  );
  return issues;
}

void _require(
  String content,
  String snippet,
  String path,
  List<String> issues,
) {
  if (!content.contains(snippet)) {
    issues.add('Missing "$snippet" in $path.');
  }
}

import 'dart:io';

import 'ai_provider_contract.dart';

void main() {
  final entry = File(aiProviderEntryPath).readAsStringSync();
  final adapter = File(interactionsAdapterPath).readAsStringSync();
  final registry = File(modelRegistryPath).readAsStringSync();
  final budget = File(aiBudgetPath).readAsStringSync();

  final current = verifyAiBootstrapContract(
    entry: entry,
    adapter: adapter,
    registry: registry,
    budget: budget,
  );
  if (current.isNotEmpty) throw StateError(current.join('\n'));

  void requiresFailure(String label, List<String> issues) {
    if (issues.isEmpty) throw StateError('$label must fail closed.');
  }

  requiresFailure(
    'missing privacy storage control',
    verifyStatelessAiPath(
      entry: entry,
      adapter: adapter.replaceFirst('store: false', 'store: true'),
    ),
  );
  requiresFailure(
    'disconnected entry adapter',
    verifyStatelessAiPath(
      entry: entry.replaceFirst('callGeminiInteraction({', 'otherProvider({'),
      adapter: adapter,
    ),
  );
  requiresFailure(
    'missing budget admission',
    verifyAiBootstrapContract(
      entry: entry,
      adapter: adapter.replaceFirst('reserveAiBudget(', 'unmeteredCall('),
      registry: registry,
      budget: budget,
    ),
  );
  requiresFailure(
    'preview guard removed',
    verifyAiBootstrapContract(
      entry: entry,
      adapter: adapter,
      registry: registry.replaceFirst(
        'if (definition.releaseType === "preview" && !allowPreview)',
        'if (false)',
      ),
      budget: budget,
    ),
  );
  stdout.writeln('AI Provider contract tests: PASS.');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/performance_budget.dart';
import 'package:questra/core/performance/performance_limits.dart';

void main() {
  test('defines every beta performance budget area', () {
    final areas = PerformanceBudgetCatalog.budgets
        .map((budget) => budget.area)
        .toSet();

    expect(areas, containsAll(PerformanceBudgetArea.values));
    expect(
      PerformanceBudgetCatalog.betaRequiredBudgets.length,
      PerformanceBudgetArea.values.length,
    );
  });

  test('keeps documented budgets aligned with performance limits', () {
    final arcAssetBudget = PerformanceBudgetCatalog.budgets.firstWhere(
      (budget) => budget.area == PerformanceBudgetArea.arcAssetBytes,
    );
    final arcMemoryBudget = PerformanceBudgetCatalog.budgets.firstWhere(
      (budget) => budget.area == PerformanceBudgetArea.arcMemoryRead,
    );
    final trailImageBudget = PerformanceBudgetCatalog.budgets.firstWhere(
      (budget) => budget.area == PerformanceBudgetArea.trailImagePreUpload,
    );

    expect(
      arcAssetBudget.target,
      contains(QuestraPerformanceLimits.arcAssetMaxBytes.toString()),
    );
    expect(
      arcMemoryBudget.target,
      contains(QuestraPerformanceLimits.arcMemoryVisibleLimit.toString()),
    );
    expect(
      trailImageBudget.target,
      contains(QuestraPerformanceLimits.trailImageQuality.toString()),
    );
  });
}

import 'performance_limits.dart';

enum PerformanceBudgetArea {
  homeFirstRender,
  questTrailListRender,
  routeTransition,
  scrolling,
  arcThinkingFeedback,
  arcAssetBytes,
  trailImagePreUpload,
  supabaseListQuery,
  arcMemoryRead,
}

class PerformanceBudget {
  const PerformanceBudget({
    required this.area,
    required this.label,
    required this.target,
    required this.checkMethod,
    required this.betaRequired,
  });

  final PerformanceBudgetArea area;
  final String label;
  final String target;
  final String checkMethod;
  final bool betaRequired;
}

class PerformanceBudgetCatalog {
  const PerformanceBudgetCatalog._();

  static const budgets = [
    PerformanceBudget(
      area: PerformanceBudgetArea.homeFirstRender,
      label: 'Home初回表示',
      target: '1.5秒以内',
      checkMethod: 'profile build on physical device or Chrome profile trace',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.questTrailListRender,
      label: 'Quest/Trail一覧表示',
      target: '1秒以内',
      checkMethod: 'profile trace after repository-backed list load',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.routeTransition,
      label: '画面遷移',
      target: '300ms以内',
      checkMethod: 'Flutter DevTools frame chart',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.scrolling,
      label: 'スクロール',
      target: '60fps目標',
      checkMethod: 'Flutter DevTools frame chart while scrolling long lists',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.arcThinkingFeedback,
      label: 'Arc応答待機',
      target: '待機中UIを即時表示',
      checkMethod: 'Arc Chat manual interaction and widget state review',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.arcAssetBytes,
      label: 'Arc PNG容量',
      target: '${QuestraPerformanceLimits.arcAssetMaxBytes} bytes以下',
      checkMethod: 'dart run tools/qst/verify_performance_readiness.dart',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.trailImagePreUpload,
      label: 'Trail画像投稿前圧縮',
      target:
          '${QuestraPerformanceLimits.trailImageMaxWidth}px / quality ${QuestraPerformanceLimits.trailImageQuality}',
      checkMethod: 'image_picker options review',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.supabaseListQuery,
      label: 'Supabase一覧取得',
      target: 'limitと明示カラムを使用',
      checkMethod: 'repository query review and verifier script',
      betaRequired: true,
    ),
    PerformanceBudget(
      area: PerformanceBudgetArea.arcMemoryRead,
      label: 'Arc Memory取得',
      target: '${QuestraPerformanceLimits.arcMemoryVisibleLimit}件以内',
      checkMethod: 'repository query review and verifier script',
      betaRequired: true,
    ),
  ];

  static List<PerformanceBudget> get betaRequiredBudgets {
    return budgets.where((budget) => budget.betaRequired).toList();
  }
}

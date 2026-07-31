import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../quest/planning_context.dart';
import '../../quest/planning_preferences.dart';
import '../../quest/planning_preferences_controller.dart';
import '../../quest/weekly_availability.dart';

class PlanningPreferencesCard extends ConsumerWidget {
  const PlanningPreferencesCard({super.key});

  static const _minuteOptions = [0, 15, 30, 45, 60, 90, 120, 180];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(planningPreferencesControllerProvider);
    final controller = ref.read(planningPreferencesControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.84),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '航路に使える時間',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '各曜日にQuestへ使える時間を選びます。外部カレンダーには接続しません。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchment,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: Weekday.values
                .map(
                  (day) => _DayAvailabilityControl(
                    day: day,
                    value: preferences.availability.minutesFor(day),
                    options: _minuteOptions,
                    onChanged: (minutes) => unawaited(
                      controller.apply(
                        preferences.copyWith(
                          availability: preferences.availability.copyWithDay(
                            day,
                            minutes,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '週合計 ${_durationLabel(preferences.availability.totalMinutes)}',
            style: const TextStyle(
              color: AppColors.skyBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          Divider(
            height: AppSpacing.xl,
            color: AppColors.skyBlue.withValues(alpha: 0.18),
          ),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.route_outlined,
                color: AppColors.gold,
              ),
              title: const Text(
                'Arcの航路設計に利用',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: const Text(
                '登録した時間と計画条件を、Mission数や進め方の調整に使います。',
                style: TextStyle(color: AppColors.parchment),
              ),
              value: preferences.context.consentGranted,
              onChanged: (value) => unawaited(
                controller.apply(
                  preferences.copyWith(
                    context: preferences.context.copyWith(
                      consentGranted: value,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (preferences.context.consentGranted) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editContext(context, controller, preferences),
                icon: const Icon(Icons.tune_rounded),
                label: Text(_contextSummary(preferences.context)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editContext(
    BuildContext context,
    PlanningPreferencesController controller,
    PlanningPreferences preferences,
  ) async {
    final location = TextEditingController(text: preferences.context.location);
    final resources = TextEditingController(
      text: preferences.context.availableResources.join('、'),
    );
    final preferenceText = TextEditingController(
      text: preferences.context.preferences.join('、'),
    );
    var budget = preferences.context.budgetLabel ?? '未設定';
    var experience = preferences.context.experience ?? '未設定';
    final result = await showDialog<PlanningContext>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('航路の条件'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _FieldLabel('予算の目安'),
                DropdownButtonFormField<String>(
                  initialValue: budget,
                  decoration: const InputDecoration(hintText: '選択'),
                  items: const ['未設定', 'できるだけ無料', '1万円未満', '1〜5万円', '5万円以上']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setDialogState(() => budget = value ?? budget),
                ),
                const SizedBox(height: AppSpacing.md),
                const _FieldLabel('経験'),
                DropdownButtonFormField<String>(
                  initialValue: experience,
                  decoration: const InputDecoration(hintText: '選択'),
                  items: const ['未設定', '初めて', '少し経験がある', '経験がある']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setDialogState(() => experience = value ?? experience),
                ),
                const SizedBox(height: AppSpacing.md),
                const _FieldLabel('場所・地域'),
                TextField(
                  controller: location,
                  maxLength: 120,
                  decoration: const InputDecoration(hintText: '例：東京、オンライン'),
                ),
                const _FieldLabel('使えるもの'),
                TextField(
                  controller: resources,
                  maxLength: 240,
                  decoration: const InputDecoration(hintText: '例：パソコン、自転車'),
                ),
                const _FieldLabel('進め方の希望'),
                TextField(
                  controller: preferenceText,
                  maxLength: 240,
                  decoration: const InputDecoration(hintText: '例：休日中心、費用を抑える'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                preferences.context.copyWith(
                  budgetLabel: budget == '未設定' ? '' : budget,
                  experience: experience == '未設定' ? '' : experience,
                  location: location.text.trim(),
                  availableResources: _splitValues(resources.text),
                  preferences: _splitValues(preferenceText.text),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    location.dispose();
    resources.dispose();
    preferenceText.dispose();
    if (result != null) {
      await controller.apply(preferences.copyWith(context: result));
    }
  }

  static List<String> _splitValues(String value) => value
      .split(RegExp('[,、\\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(20)
      .toList(growable: false);

  static String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes分';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours時間' : '$hours時間$rest分';
  }

  static String _contextSummary(PlanningContext context) {
    final values = [context.experience, context.budgetLabel, context.location]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? '計画条件を追加' : values.join(' ・ ');
  }
}

class _DayAvailabilityControl extends StatelessWidget {
  const _DayAvailabilityControl({
    required this.day,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final Weekday day;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Text(
            '${day.shortLabel}曜',
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          DropdownButton<int>(
            value: options.contains(value) ? value : 0,
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.midnightNavy,
            style: const TextStyle(
              color: AppColors.skyBlue,
              fontWeight: FontWeight.w800,
            ),
            items: options
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text(minutes == 0 ? '休み' : '$minutes分'),
                  ),
                )
                .toList(growable: false),
            onChanged: (minutes) {
              if (minutes != null) onChanged(minutes);
            },
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

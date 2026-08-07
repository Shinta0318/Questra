import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/experience/experience_settings.dart';
import '../../../core/experience/experience_settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class ExperienceSettingsCard extends ConsumerWidget {
  const ExperienceSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(experienceSettingsControllerProvider);
    final controller = ref.read(experienceSettingsControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.84),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_motion, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '体験・演出',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SettingLabel(label: 'Arcアニメーション'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ArcMotionLevel>(
              segments: ArcMotionLevel.values
                  .map(
                    (level) => ButtonSegment(
                      value: level,
                      label: Text(level.label),
                    ),
                  )
                  .toList(growable: false),
              selected: {settings.arcMotionLevel},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => controller.apply(
                settings.copyWith(arcMotionLevel: selection.single),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SettingLabel(label: '達成演出'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<CompletionEffectLevel>(
              segments: CompletionEffectLevel.values
                  .map(
                    (level) => ButtonSegment(
                      value: level,
                      label: Text(level.label),
                    ),
                  )
                  .toList(growable: false),
              selected: {settings.completionEffectLevel},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => controller.apply(
                settings.copyWith(completionEffectLevel: selection.single),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ExperienceSwitch(
            icon: Icons.vibration_rounded,
            label: '触覚フィードバック',
            value: settings.hapticsEnabled,
            onChanged: (value) => controller.apply(
              settings.copyWith(hapticsEnabled: value),
            ),
          ),
          _ExperienceSwitch(
            icon: Icons.volume_up_outlined,
            label: '効果音',
            value: settings.soundEffectsEnabled,
            onChanged: (value) => controller.apply(
              settings.copyWith(soundEffectsEnabled: value),
            ),
          ),
          _ExperienceSwitch(
            icon: Icons.swipe_rounded,
            label: 'スワイプ操作',
            value: settings.swipeGesturesEnabled,
            onChanged: (value) => controller.apply(
              settings.copyWith(swipeGesturesEnabled: value),
            ),
          ),
          _ExperienceSwitch(
            icon: Icons.motion_photos_off_outlined,
            label: '画面アニメーションを軽減',
            value: settings.motionPreference == MotionPreference.reduced,
            onChanged: (value) => controller.apply(
              settings.copyWith(
                motionPreference: value
                    ? MotionPreference.reduced
                    : MotionPreference.standard,
              ),
            ),
          ),
          _ExperienceSwitch(
            icon: Icons.battery_saver_outlined,
            label: '省電力モード',
            value: settings.powerSavingMode,
            onChanged: (value) => controller.apply(
              settings.copyWith(powerSavingMode: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.parchment,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _ExperienceSwitch extends StatelessWidget {
  const _ExperienceSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: AppColors.skyBlue),
        title: Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

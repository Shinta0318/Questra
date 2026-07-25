import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/experience/experience_settings.dart';
import '../../core/experience/experience_settings_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_guide_controller.dart';
import '../quest/quest_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController(text: '旅人');
  final _arcNameController = TextEditingController(text: 'Arc');
  final _questController = TextEditingController();
  QuestInterest _questInterest = QuestInterest.adventure;
  SignalFrequency _signalFrequency = SignalFrequency.balanced;
  ExperiencePreset _experiencePreset = ExperiencePreset.quiet;
  int _step = 0;

  @override
  void dispose() {
    _nicknameController.dispose();
    _arcNameController.dispose();
    _questController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('はじまりの航路')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          maxContentWidth: 640,
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: QuestraCard(child: _buildStep(context)),
            ),
            const SizedBox(height: 20),
            QuestraPrimaryButton(
              label: _step == 4 ? '旅を始める' : '次へ',
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return switch (_step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: ArcWidget(
                emotion: ArcEmotion.excited,
                message: 'ぼくはArc。君の願いを、最初のQuestという星に変える案内役だよ。',
              ),
            ),
            const SizedBox(height: 20),
            Text('Arcとの初対面', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('呼び名を決める', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            QuestraFieldLabel(
              label: 'あなたの呼び名',
              required: true,
              child: TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(hintText: '例: シンタ'),
                maxLength: InputLimits.nickname,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: '呼び名',
                  maxLength: InputLimits.nickname,
                ),
              ),
            ),
            const SizedBox(height: 12),
            QuestraFieldLabel(
              label: 'Arcの呼び方',
              required: true,
              child: TextFormField(
                controller: _arcNameController,
                decoration: const InputDecoration(hintText: '例: Arc'),
                maxLength: InputLimits.arcName,
                validator: (value) => InputValidators.requiredText(
                  value,
                  fieldName: 'Arcの呼び方',
                  maxLength: InputLimits.arcName,
                ),
              ),
            ),
          ],
        ),
      2 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('旅の傾向', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text('今いちばん近いQuestの方向を選んでください。'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuestInterest.values.map((interest) {
                return ChoiceChip(
                  label: Text(interest.label),
                  selected: _questInterest == interest,
                  onSelected: (_) => setState(() => _questInterest = interest),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Signal頻度', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SignalFrequency.values.map((frequency) {
                return ChoiceChip(
                  label: Text(frequency.label),
                  selected: _signalFrequency == frequency,
                  onSelected: (_) =>
                      setState(() => _signalFrequency = frequency),
                );
              }).toList(),
            ),
          ],
        ),
      3 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Questraの演出',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text('心地よい航海のテンポを選んでください。'),
            const SizedBox(height: 16),
            RadioGroup<ExperiencePreset>(
              groupValue: _experiencePreset,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _experiencePreset = value);
                }
              },
              child: Column(
                children: ExperiencePreset.values
                    .map(
                      (preset) => Material(
                        type: MaterialType.transparency,
                        child: RadioListTile<ExperiencePreset>(
                          value: preset,
                          title: Text(_experiencePresetLabel(preset)),
                          secondary: Icon(_experiencePresetIcon(preset)),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最初のQuest', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            QuestraFieldLabel(
              label: '最初に叶えたいことは？',
              child: TextFormField(
                controller: _questController,
                decoration: const InputDecoration(
                  hintText: 'まだ曖昧でも大丈夫です',
                ),
                maxLength: InputLimits.questTitle,
                validator: (value) => InputValidators.optionalText(
                  value,
                  fieldName: '最初のQuest',
                  maxLength: InputLimits.questTitle,
                ),
              ),
            ),
          ],
        ),
    };
  }

  Future<void> _next() async {
    if ((_step == 1 || _step == 4) &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }
    if (_step < 4) {
      setState(() => _step += 1);
      return;
    }

    final nickname = _nicknameController.text.trim();
    final arcName = _arcNameController.text.trim();
    final questTitle = _questController.text.trim().isEmpty
        ? _defaultQuestTitle(_questInterest)
        : _questController.text.trim();

    await ref.read(authControllerProvider.notifier).completeOnboarding(
          nickname: nickname,
          arcName: arcName,
          questInterest: _questInterest,
          signalFrequency: _signalFrequency,
        );
    await ref
        .read(experienceSettingsControllerProvider.notifier)
        .applyPreset(_experiencePreset);
    unawaited(
      ref.read(analyticsServiceProvider).onboardingCompleted(
            userId: ref.read(authControllerProvider).profile?.id,
            questInterest: _questInterest.storageKey,
            signalFrequency: _signalFrequency.storageKey,
          ),
    );
    final quest = Quest(
      title: questTitle,
      description: '$arcNameと一緒に、はじまりの航路で作ったQuest。',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: _questInterest.label,
      targetDate: DateTime.now().add(const Duration(days: 14)),
    );
    ref.read(questControllerProvider.notifier).add(quest);
    ref.read(questGuideControllerProvider.notifier).generateForQuest(quest);

    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  String _defaultQuestTitle(QuestInterest interest) {
    return switch (interest) {
      QuestInterest.adventure => '最初のQuestraの旅を始める',
      QuestInterest.learning => '新しい学びを一歩進める',
      QuestInterest.health => '健康の小さな習慣を作る',
      QuestInterest.work => '仕事の挑戦を前に進める',
      QuestInterest.family => '大切な人との時間を作る',
      QuestInterest.challenge => '勇気のいる挑戦を始める',
    };
  }

  String _experiencePresetLabel(ExperiencePreset preset) {
    return switch (preset) {
      ExperiencePreset.full => 'フル体験',
      ExperiencePreset.quiet => '静かな体験',
      ExperiencePreset.simple => 'シンプル',
    };
  }

  IconData _experiencePresetIcon(ExperiencePreset preset) {
    return switch (preset) {
      ExperiencePreset.full => Icons.auto_awesome_rounded,
      ExperiencePreset.quiet => Icons.nights_stay_outlined,
      ExperiencePreset.simple => Icons.minimize_rounded,
    };
  }
}

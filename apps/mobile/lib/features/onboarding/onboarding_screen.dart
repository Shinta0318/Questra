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
import 'onboarding_draft_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = <int>[0, 1, 4];
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController(text: '旅人');
  final _arcNameController = TextEditingController(text: 'Arc');
  final _questController = TextEditingController();
  QuestInterest _questInterest = QuestInterest.adventure;
  SignalFrequency _signalFrequency = SignalFrequency.balanced;
  ExperiencePreset _experiencePreset = ExperiencePreset.quiet;
  int _step = 0;
  Timer? _draftSaveTimer;
  String? _draftOwnerId;
  bool _draftRestored = false;
  bool _isCompleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_scheduleDraftSave);
    _arcNameController.addListener(_scheduleDraftSave);
    _questController.addListener(_scheduleDraftSave);
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _nicknameController.dispose();
    _arcNameController.dispose();
    _questController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = ref.watch(authControllerProvider).profile?.id;
    if (_draftOwnerId != ownerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _draftOwnerId != ownerId) {
          unawaited(_restoreDraft(ownerId));
        }
      });
    }
    final stepIndex = _steps.indexOf(_step).clamp(0, _steps.length - 1);
    return Scaffold(
      appBar: AppBar(title: const Text('はじまりの航路')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          maxContentWidth: 640,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ステップ ${stepIndex + 1} / ${_steps.length}',
                    key: const ValueKey('onboarding-progress-label'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                TextButton(
                  key: const ValueKey('onboarding-skip'),
                  onPressed: _isCompleting || !_draftRestored ? null : _skip,
                  child: const Text('後で設定'),
                ),
              ],
            ),
            Semantics(
              label: 'オンボーディングの進捗',
              value: '${stepIndex + 1}/${_steps.length}',
              child: LinearProgressIndicator(
                value: (stepIndex + 1) / _steps.length,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: QuestraCard(child: _buildStep(context)),
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: const ValueKey('onboarding-save-error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (stepIndex > 0) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('onboarding-back'),
                    onPressed: _isCompleting || !_draftRestored
                        ? null
                        : _previous,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('戻る'),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: QuestraPrimaryButton(
                    label: _isCompleting
                        ? '保存しています...'
                        : _step == 4
                        ? '旅を始める'
                        : '次へ',
                    onPressed: _isCompleting || !_draftRestored ? null : _next,
                  ),
                ),
              ],
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
          const SizedBox(height: 12),
          const Text('願いを話すと、ArcがQuestと最初のMissionを一緒に整理します。'),
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
                onSelected: (_) => setState(() => _signalFrequency = frequency),
              );
            }).toList(),
          ),
        ],
      ),
      3 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questraの演出', style: Theme.of(context).textTheme.headlineMedium),
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
              decoration: const InputDecoration(hintText: 'まだ曖昧でも大丈夫です'),
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
    final index = _steps.indexOf(_step);
    if (index >= 0 && index < _steps.length - 1) {
      _setStep(_steps[index + 1]);
      return;
    }

    await _complete(createQuest: true, destination: AppRoutes.home);
  }

  void _previous() {
    final index = _steps.indexOf(_step);
    if (index <= 0) return;
    _setStep(_steps[index - 1]);
  }

  void _setStep(int step) {
    setState(() => _step = step);
    _scheduleDraftSave();
  }

  Future<void> _skip() async {
    await _complete(createQuest: false, destination: AppRoutes.arc);
  }

  Future<void> _complete({
    required bool createQuest,
    required String destination,
  }) async {
    if (_isCompleting) return;
    setState(() {
      _isCompleting = true;
      _errorMessage = null;
    });

    try {
      final nickname = _nicknameController.text.trim().isEmpty
          ? '旅人'
          : _nicknameController.text.trim();
      final arcName = _arcNameController.text.trim().isEmpty
          ? 'Arc'
          : _arcNameController.text.trim();
      final questTitle = _questController.text.trim().isEmpty
          ? _defaultQuestTitle(_questInterest)
          : _questController.text.trim();

      await ref
          .read(authControllerProvider.notifier)
          .completeOnboarding(
            nickname: nickname,
            arcName: arcName,
            questInterest: _questInterest,
            signalFrequency: _signalFrequency,
          );
      await ref
          .read(experienceSettingsControllerProvider.notifier)
          .applyPreset(_experiencePreset);
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .onboardingCompleted(
              userId: ref.read(authControllerProvider).profile?.id,
              questInterest: _questInterest.storageKey,
              signalFrequency: _signalFrequency.storageKey,
            ),
      );
      if (createQuest) {
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
      }
      await _clearDraft();

      if (mounted) context.go(destination);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCompleting = false;
        _errorMessage = '設定を保存できませんでした。入力内容を残したまま、もう一度試せます。';
      });
    }
  }

  Future<void> _restoreDraft(String? ownerId) async {
    _draftOwnerId = ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      if (mounted) setState(() => _draftRestored = true);
      return;
    }
    final draft = await ref
        .read(onboardingDraftRepositoryProvider)
        .load(ownerId);
    if (!mounted || _draftOwnerId != ownerId) return;
    if (draft != null) {
      _step = draft.step;
      _nicknameController.text = draft.nickname.isEmpty
          ? _nicknameController.text
          : draft.nickname;
      _arcNameController.text = draft.arcName.isEmpty
          ? _arcNameController.text
          : draft.arcName;
      _questController.text = draft.questWish;
    }
    setState(() => _draftRestored = true);
  }

  void _scheduleDraftSave() {
    if (!_draftRestored || _isCompleting || _draftOwnerId == null) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 300), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final ownerId = _draftOwnerId;
    if (ownerId == null || ownerId.isEmpty || _isCompleting) return;
    try {
      await ref
          .read(onboardingDraftRepositoryProvider)
          .save(
            ownerId,
            OnboardingDraft(
              step: _step,
              nickname: _nicknameController.text,
              arcName: _arcNameController.text,
              questWish: _questController.text,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '途中保存ができませんでした。この画面を閉じずに続けてください。';
      });
    }
  }

  Future<void> _clearDraft() async {
    _draftSaveTimer?.cancel();
    final ownerId = _draftOwnerId;
    if (ownerId == null || ownerId.isEmpty) return;
    try {
      await ref.read(onboardingDraftRepositoryProvider).clear(ownerId);
    } catch (_) {
      // Completion must not be blocked by best-effort local draft cleanup.
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

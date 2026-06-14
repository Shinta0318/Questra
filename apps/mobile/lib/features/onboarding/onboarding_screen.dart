import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import '../auth/auth_controller.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_guide_controller.dart';
import '../quest/quest_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nicknameController = TextEditingController(text: '旅人');
  final _questController = TextEditingController();
  int _step = 0;

  @override
  void dispose() {
    _nicknameController.dispose();
    _questController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('はじまりの航路')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            QuestraCard(child: _buildStep(context)),
            const SizedBox(height: 20),
            QuestraPrimaryButton(
              label: _step == 2 ? '旅を始める' : '次へ',
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
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(labelText: '呼び名'),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最初のQuest', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _questController,
            decoration: const InputDecoration(labelText: '最初に叶えたいことは？'),
          ),
        ],
      ),
    };
  }

  Future<void> _next() async {
    if (_step < 2) {
      setState(() => _step += 1);
      return;
    }

    final nickname = _nicknameController.text.trim().isEmpty
        ? '旅人'
        : _nicknameController.text.trim();
    final questTitle = _questController.text.trim().isEmpty
        ? '最初のQuestraの旅を始める'
        : _questController.text.trim();

    await ref
        .read(authControllerProvider.notifier)
        .completeOnboarding(nickname: nickname);
    final quest = Quest(
      title: questTitle,
      description: 'Arcと一緒に、はじまりの航路で作ったQuest。',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime.now().add(const Duration(days: 14)),
    );
    ref.read(questControllerProvider.notifier).add(quest);
    ref.read(questGuideControllerProvider.notifier).generateForQuest(quest);

    if (mounted) {
      context.go(AppRoutes.home);
    }
  }
}

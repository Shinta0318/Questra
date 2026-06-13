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
import '../quest/quest_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nicknameController = TextEditingController(text: 'Adventurer');
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
      appBar: AppBar(title: const Text('Onboarding')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            QuestraCard(child: _buildStep(context)),
            const SizedBox(height: 20),
            QuestraPrimaryButton(
              label: _step == 2 ? 'Begin' : 'Next',
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
              message: 'I am Arc. I will help turn your goals into quests.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Arc Greeting',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nickname Setup',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(labelText: 'Nickname'),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'First Quest Input',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questController,
            decoration: const InputDecoration(
              labelText: 'What do you want to pursue first?',
            ),
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
        ? 'Adventurer'
        : _nicknameController.text.trim();
    final questTitle = _questController.text.trim().isEmpty
        ? 'Start my first Questra adventure'
        : _questController.text.trim();

    await ref
        .read(authControllerProvider.notifier)
        .completeOnboarding(nickname: nickname);
    ref
        .read(questControllerProvider.notifier)
        .add(
          Quest(
            title: questTitle,
            description: 'Created during onboarding with Arc.',
            difficulty: QuestDifficulty.normal,
            status: QuestStatus.active,
            visibility: QuestVisibility.private,
            targetDate: DateTime.now().add(const Duration(days: 14)),
          ),
        );

    if (mounted) {
      context.go(AppRoutes.home);
    }
  }
}

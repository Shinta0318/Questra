import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/estimation/effort_estimation_service.dart';
import '../../core/router/app_routes.dart';
import '../../core/safety/quest_safety_service.dart';
import '../../core/safety/safety_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_field_sizes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_approved_portrait.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../../widgets/forms/arc_chat_keyboard_contract.dart';
import '../../widgets/forms/year_month_picker.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../../widgets/questra_card.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_contract_service.dart';
import '../mission/mission_model.dart';
import '../quest/arc_quest_guide_controller.dart';
import '../quest/arc_quest_guide_service.dart';
import '../quest/quest_clarification_service.dart';
import '../quest/quest_controller.dart';
import '../quest/quest_feasibility_service.dart';
import '../quest/quest_intent_model.dart';
import '../quest/quest_intent_service.dart';
import '../quest/quest_intent_resolution_service.dart';
import '../quest/quest_model.dart';
import '../quest/planning_preferences_controller.dart';
import '../quest/quest_guide_model.dart';
import '../trail/trail_controller.dart';
import '../trail/trail_model.dart';
import '../task/task_controller.dart';
import '../task/task_model.dart';
import '../signal/signal_providers.dart';
import '../signal/task_signal_card.dart';
import 'arc_bond_growth_service.dart';
import 'arc_chat_service.dart';
import 'arc_quest_change_proposal.dart';
import 'arc_quest_clarification_session.dart';
import 'arc_quick_action.dart';
import 'arc_emotion_timeline_controller.dart';
import 'arc_emotion_timeline_model.dart';
import 'arc_guidance_providers.dart';
import 'arc_action_trigger_service.dart';
import 'stardust_service.dart';

const _missionUuid = Uuid();

class ArcScreen extends ConsumerStatefulWidget {
  const ArcScreen({
    super.key,
    this.initialPrompt,
    this.focusQuestId,
    this.focusMissionId,
    this.returnLocation,
  });

  final String? initialPrompt;
  final String? focusQuestId;
  final String? focusMissionId;
  final String? returnLocation;

  @override
  ConsumerState<ArcScreen> createState() => _ArcScreenState();
}

class _ArcScreenState extends ConsumerState<ArcScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ArcChatMessage> _messages = [
    ArcChatMessage(
      text: 'おかえり。今日は、どんなことが気になってる？',
      fromArc: true,
      createdAt: DateTime.now(),
    ),
  ];
  List<String> _quickActions = const [
    'やりたいことを相談',
    'Questを作る',
    '今日の一歩を決める',
    '計画を見直す',
    '情報を調べる',
  ];
  bool _isThinking = false;
  String? _chatInputError;
  ArcQuestSuggestion? _pendingQuestSuggestion;
  ArcQuestClarificationSession? _clarificationSession;
  List<ArcQuestChangeProposal> _pendingQuestChanges = const [];
  String? _appliedLaunchKey;

  @override
  void initState() {
    super.initState();
    _applyLaunchContext();
  }

  @override
  void didUpdateWidget(covariant ArcScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyLaunchContext();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quests = ref.watch(questControllerProvider);
    final missions = ref.watch(missionControllerProvider);
    final trails = ref.watch(trailControllerProvider);
    final tasks = ref.watch(taskControllerProvider);
    final profile = ref.watch(authControllerProvider).profile;
    final memories = ref.watch(visibleArcMemoriesProvider);
    final emotionEvents = ref.watch(arcEmotionTimelineControllerProvider);
    final focusQuest = quests
        .where((quest) => quest.id == widget.focusQuestId)
        .firstOrNull;
    final focusMission = missions
        .where((mission) => mission.id == widget.focusMissionId)
        .firstOrNull;
    final returnLocation = _safeReturnLocation;
    final taskSignals = ref
        .watch(taskSignalServiceProvider)
        .generate(
          tasks: tasks,
          now: DateTime.now(),
          frequency: profile?.signalFrequency ?? SignalFrequency.balanced,
        );

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: QuestraScreenSurface(
        child: Column(
          children: [
            _ArcHeader(
              onBack: returnLocation == null
                  ? null
                  : () => context.go(returnLocation),
            ),
            Expanded(
              child: QuestraResponsiveListView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  if (focusMission != null) ...[
                    _ArcMissionContextCard(
                      questTitle: focusQuest?.title ?? focusMission.questTitle,
                      missionTitle: focusMission.title,
                      onOpenMission: returnLocation == null
                          ? null
                          : () => context.go(returnLocation),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (taskSignals.isNotEmpty) ...[
                    TaskSignalCard(
                      signal: taskSignals.first,
                      onOpen: () {
                        final signal = taskSignals.first;
                        context.push(
                          AppRoutes.taskDetail(
                            signal.questId,
                            signal.missionId,
                            signal.taskId,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _ArcCommandCenterCard(
                    activeQuestCount: quests
                        .where((quest) => quest.status == QuestStatus.active)
                        .length,
                    missionCount: missions.length,
                    trailCount: trails.length,
                    onOpenQuest: () => context.go(AppRoutes.quest),
                    onCreateQuest: () => _openQuestCreation(),
                    onOpenTrail: () => context.go(AppRoutes.trail),
                    onHorizon: () => _send(
                      '次の挑戦の候補を一緒に探したい。',
                      quests: quests,
                      missions: missions,
                      trails: trails,
                      memories: memories.asData?.value ?? const [],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (var index = 0; index < _messages.length; index++)
                    _ArcMessageBubble(
                      text: _messages[index].text,
                      fromArc: _messages[index].fromArc,
                      showIdentity:
                          _messages[index].fromArc &&
                          (index == 0 || !_messages[index - 1].fromArc),
                      emotion: _messages[index].fromArc
                          ? ArcEmotion.support
                          : ArcEmotion.normal,
                    ),
                  if (_pendingQuestSuggestion case final suggestion?) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ArcQuestSuggestionCard(
                      suggestion: suggestion,
                      onPlan: () => _openQuestCreation(suggestion: suggestion),
                      onDismiss: () =>
                          setState(() => _pendingQuestSuggestion = null),
                    ),
                  ],
                  if (_clarificationSession case final session?) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ArcClarificationCard(session: session),
                  ],
                  if (_pendingQuestChanges.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ArcQuestChangesCard(
                      proposals: _pendingQuestChanges,
                      quests: quests,
                      missions: missions,
                      onApply: (proposal) =>
                          _applyQuestChange(proposal, quests, missions),
                      onLater: (proposal) => _removeQuestChange(proposal),
                      onReject: (proposal) =>
                          _removeQuestChange(proposal, addFeedback: true),
                      onOpenQuest: (proposal) =>
                          context.go('${AppRoutes.quest}/${proposal.questId}'),
                    ),
                  ],
                  if (_isThinking) const _ArcThinkingBubble(),
                  const SizedBox(height: AppSpacing.sm),
                  if (_clarificationSession == null)
                    _ArcActionCard(
                      actions: _quickActions,
                      onQuickAction: (action) => _send(
                        action.prompt,
                        quests: quests,
                        missions: missions,
                        trails: trails,
                        memories: memories.asData?.value ?? const [],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _ArcDetailsDisclosure(
                    events: emotionEvents,
                    memoryIsEmpty: (memories.asData?.value ?? const []).isEmpty,
                    onOpenQuest: () => context.go(AppRoutes.quest),
                  ),
                ],
              ),
            ),
            _ArcInputBar(
              controller: _controller,
              errorText: _chatInputError,
              isSending: _isThinking,
              onChanged: (_) {
                if (_chatInputError != null) {
                  setState(() => _chatInputError = null);
                }
              },
              onSend: () {
                _send(
                  _controller.text,
                  quests: quests,
                  missions: missions,
                  trails: trails,
                  memories: memories.asData?.value ?? const [],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _applyLaunchContext() {
    final prompt = widget.initialPrompt?.trim() ?? '';
    final key = '${widget.focusQuestId}|${widget.focusMissionId}|$prompt';
    if (prompt.isEmpty || _appliedLaunchKey == key) return;
    _appliedLaunchKey = key;
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
  }

  String? get _safeReturnLocation {
    final value = widget.returnLocation?.trim();
    if (value == null || !value.startsWith('/quest/')) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
    return value;
  }

  Future<void> _openQuestCreation({ArcQuestSuggestion? suggestion}) async {
    final result = await showModalBottomSheet<_ArcQuestConfirmation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ArcQuestCreationSheet(suggestion: suggestion),
    );
    if (result == null || !mounted) return;

    final quest = result.quest;
    ref.read(questControllerProvider.notifier).add(quest);
    ref
        .read(arcQuestGuideControllerProvider.notifier)
        .acceptGeneratedGuide(quest, result.guide);
    final missionIds = {
      for (final mission in result.missions) mission.planKey: _missionUuid.v4(),
    };
    for (var index = 0; index < result.missions.length; index++) {
      final mission = result.missions[index];
      ref
          .read(missionControllerProvider.notifier)
          .addMissionDraft(
            quest: quest,
            id: missionIds[mission.planKey],
            title: mission.title.trim(),
            description: mission.description.trim(),
            guideType: mission.guideType,
            difficulty: mission.difficulty,
            sortOrder: index,
            isToday: index == 0,
            effortEstimate: mission.effortEstimate,
            parentMissionId: missionIds[mission.parentPlanKey],
            dependencyIds: mission.dependencyPlanKeys
                .map((key) => missionIds[key])
                .whereType<String>()
                .toList(growable: false),
            priority: mission.priority,
            category: mission.category,
            estimatedCostLabel: mission.estimatedCostLabel,
            referenceHints: mission.referenceHints,
            enterpriseSupportHints: mission.enterpriseSupportHints,
            difficultyScore: mission.difficultyScore,
            estimatedDurationDays: mission.estimatedDurationDays,
            doneCondition: mission.doneCondition,
            expectedOutput: mission.expectedOutput,
            verificationType: mission.verificationType,
            action: mission.action,
            isOptional: mission.isOptional,
            sourceRequirement: mission.sourceRequirement,
            confidence: mission.confidence,
          );
    }
    setState(() {
      _pendingQuestSuggestion = null;
      _messages.add(
        ArcChatMessage(
          text:
              '「${quest.title}」を星図に灯し、${result.missions.length}つのMissionへ分けたよ。最初の一歩から始めよう。',
          fromArc: true,
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToLatest();
    if (mounted) {
      context.go('${AppRoutes.quest}/${quest.id}');
    }
  }

  Future<void> _send(
    String rawText, {
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    required List<ArcMemory> memories,
  }) async {
    if (_isThinking) return;
    final validationError = InputValidators.arcChat(rawText);
    if (validationError != null) {
      if (mounted) setState(() => _chatInputError = validationError);
      return;
    }
    final text = rawText.trim();

    _controller.clear();
    final userMessage = ArcChatMessage(
      text: text,
      fromArc: false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _chatInputError = null;
      _messages.add(userMessage);
      _isThinking = true;
    });
    _scrollToLatest();
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .arcChatSent(
            userId: ref.read(authControllerProvider).profile?.id,
            hasQuest: quests.any((quest) => quest.status == QuestStatus.active),
            hasTrail: trails.isNotEmpty,
          ),
    );

    final focusedQuest = quests
        .where((quest) => quest.id == widget.focusQuestId)
        .firstOrNull;
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList(growable: false);
    final contextQuests = [
      ?focusedQuest,
      ...activeQuests.where((quest) => quest.id != focusedQuest?.id),
    ];
    final focusedMission = missions
        .where((mission) => mission.id == widget.focusMissionId)
        .firstOrNull;
    final contextMissions = [
      ?focusedMission,
      ...missions.where((mission) => mission.id != focusedMission?.id).take(4),
    ];
    final contextTasks =
        ref
            .read(taskControllerProvider)
            .where(
              (task) =>
                  task.isOpen &&
                  (focusedMission != null
                      ? task.missionId == focusedMission.id
                      : focusedQuest != null
                      ? task.questId == focusedQuest.id
                      : contextQuests.any((quest) => quest.id == task.questId)),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final status = _arcTaskStatusRank(
              left.status,
            ).compareTo(_arcTaskStatusRank(right.status));
            return status != 0
                ? status
                : left.orderIndex.compareTo(right.orderIndex);
          });
    final context = ArcChatContext(
      activeQuests: contextQuests,
      recentMissions: contextMissions,
      recentTasks: contextTasks.take(5).toList(growable: false),
      recentTrails: trails.take(5).toList(growable: false),
      memories: ref
          .read(arcMemoryRetrievalServiceProvider)
          .retrieve(
            memories: memories,
            query: text,
            questIds: contextQuests.map((quest) => quest.id).toSet(),
          ),
    );

    try {
      final safety = await ref.read(questSafetyServiceProvider).assess(text);
      if (safety.action != QuestSafetyAction.allow) {
        if (!mounted) return;
        setState(() {
          _messages.add(
            ArcChatMessage(
              text: safety.userMessage,
              fromArc: true,
              createdAt: DateTime.now(),
            ),
          );
          _pendingQuestSuggestion = null;
          _clarificationSession = null;
          _pendingQuestChanges = const [];
          _quickActions = safety.safeAlternative == null
              ? const ['別の相談をする']
              : [safety.safeAlternative!, '別の相談をする'];
          _isThinking = false;
        });
        unawaited(
          ref
              .read(safetySignalRecorderProvider)
              .record(
                userId: ref.read(authControllerProvider).profile?.id,
                assessment: safety,
              ),
        );
        _scrollToLatest();
        return;
      }
      if (_clarificationSession case final session?) {
        final next = session.answer(text);
        final nextQuestion = next.currentQuestion;
        final arcMessage = ArcChatMessage(
          text: next.isComplete
              ? 'ありがとう。教えてくれたことを航路へ反映したよ。内容を確認してみよう。'
              : 'ありがとう。次に、${nextQuestion!.label}',
          fromArc: true,
          createdAt: DateTime.now(),
        );
        if (!mounted) return;
        setState(() {
          _messages.add(arcMessage);
          _clarificationSession = next.isComplete ? null : next;
          _pendingQuestSuggestion = next.isComplete
              ? next.resolvedSuggestion
              : null;
          _pendingQuestChanges = const [];
          _isThinking = false;
        });
        _scrollToLatest();
        await _rememberChat(userMessage, arcMessage, context);
        return;
      }
      final response = await ref
          .read(arcChatServiceProvider)
          .send(userMessage: text, history: _messages, context: context);
      final arcMessage = ArcChatMessage(
        text:
            response.clarificationQuestions.isNotEmpty &&
                !response.message.contains(
                  response.clarificationQuestions.first.label,
                )
            ? '${response.message}\n\n${response.clarificationQuestions.first.label}'
            : response.message,
        fromArc: true,
        createdAt: DateTime.now(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(arcMessage);
        final suggestion = response.questSuggestion;
        if (suggestion != null && response.clarificationQuestions.isNotEmpty) {
          _clarificationSession = ArcQuestClarificationSession(
            suggestion: suggestion,
            questions: response.clarificationQuestions.take(3).toList(),
          );
          _pendingQuestSuggestion = null;
        } else {
          _clarificationSession = null;
          _pendingQuestSuggestion = suggestion;
        }
        _pendingQuestChanges = response.questChanges;
        _quickActions = response.quickActions.isEmpty
            ? _quickActions
            : response.quickActions.take(5).toList(growable: false);
        _isThinking = false;
      });
      _scrollToLatest();
      _recordChatAction(ArcActionTrigger.arcChatResponded);
      await _rememberChat(userMessage, arcMessage, context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          ArcChatMessage(
            text: '星雲が少しざわついているみたい。今は小さな一歩だけ一緒に選ぼう。',
            fromArc: true,
            createdAt: DateTime.now(),
          ),
        );
        _isThinking = false;
      });
      _recordChatAction(ArcActionTrigger.saveFailure);
      _scrollToLatest();
    }
  }

  Future<void> _applyQuestChange(
    ArcQuestChangeProposal proposal,
    List<Quest> quests,
    List<Mission> missions,
  ) async {
    final quest = quests
        .where((item) => item.id == proposal.questId)
        .firstOrNull;
    if (quest == null) {
      _showQuestChangeMessage('対象のQuestが見つかりません。');
      _removeQuestChange(proposal);
      return;
    }
    try {
      switch (proposal.kind) {
        case ArcQuestChangeKind.addMission:
          final hints = <String>[
            ...[proposal.referenceQuery].whereType<String>(),
            ...proposal.groundingSources.map((source) => source.url.toString()),
          ];
          ref
              .read(missionControllerProvider.notifier)
              .addMissionDraft(
                quest: quest,
                title: proposal.title,
                description: proposal.description,
                guideType: GuideType.knowledge,
                difficulty: MissionDifficulty.easy,
                referenceHints: hints.toSet().take(8).toList(growable: false),
              );
          _showQuestChangeMessage(
            '「${proposal.title}」を「${quest.title}」のMissionに追加したよ。',
          );
        case ArcQuestChangeKind.addReference:
          final mission = missions
              .where((item) => item.id == proposal.targetMissionId)
              .firstOrNull;
          if (mission == null || mission.questId != quest.id) {
            throw StateError('Mission not found');
          }
          final hints = <String>[
            ...mission.referenceHints,
            ...[proposal.referenceQuery].whereType<String>(),
            ...proposal.groundingSources.map((source) => source.url.toString()),
          ].where((item) => item.trim().isNotEmpty).toSet().take(8).toList();
          ref
              .read(missionControllerProvider.notifier)
              .updateMission(mission.copyWith(referenceHints: hints));
          _showQuestChangeMessage(
            '「${mission.title}」に参考情報の手がかりを追加したよ。Missionの実行サポートから最新情報を確認できる。',
          );
        case ArcQuestChangeKind.reviewDeadline:
          final target = proposal.proposedTargetDate;
          if (target == null) throw StateError('Target date is missing');
          ref
              .read(questControllerProvider.notifier)
              .update(quest.copyWith(targetDate: target));
          _showQuestChangeMessage(
            '「${quest.title}」の期限を${DateFormat('yyyy/MM').format(target)}に更新したよ。',
          );
        default:
          context.go('${AppRoutes.quest}/${proposal.questId}');
          return;
      }
      _removeQuestChange(proposal);
    } on ArgumentError catch (error) {
      _showQuestChangeMessage(
        error.message?.toString() ?? '同じMissionがすでにあるみたい。',
      );
      _removeQuestChange(proposal);
    } catch (_) {
      _showQuestChangeMessage('今は反映できなかった。Questの詳細からもう一度確認してみて。');
    }
  }

  void _removeQuestChange(
    ArcQuestChangeProposal proposal, {
    bool addFeedback = false,
  }) {
    setState(() {
      _pendingQuestChanges = _pendingQuestChanges
          .where((item) => item.id != proposal.id)
          .toList(growable: false);
      if (addFeedback) {
        _messages.add(
          ArcChatMessage(
            text: 'わかった。今の航路はそのままにしておくね。',
            fromArc: true,
            createdAt: DateTime.now(),
          ),
        );
      }
    });
  }

  void _showQuestChangeMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ArcChatMessage(text: message, fromArc: true, createdAt: DateTime.now()),
      );
    });
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _recordChatAction(ArcActionTrigger trigger) {
    final decision = ref
        .read(arcActionTriggerServiceProvider)
        .resolve(trigger: trigger, surface: 'Arc Chat');
    ref
        .read(arcEmotionTimelineControllerProvider.notifier)
        .record(
          emotion: decision.emotion,
          sourceType: decision.sourceType,
          reason: decision.message,
        );
  }

  Future<void> _rememberChat(
    ArcChatMessage userMessage,
    ArcChatMessage arcMessage,
    ArcChatContext context,
  ) async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      return;
    }
    final quest = context.activeQuests.isEmpty
        ? null
        : context.activeQuests.first;
    final trail = context.recentTrails.isEmpty
        ? null
        : context.recentTrails.first;
    try {
      await ref
          .read(memoryExtractionServiceProvider)
          .extractAndSave(
            MemoryExtractionEvent(
              userId: profile.id,
              questId: quest?.id,
              trailId: trail?.id,
              sourceType: ArcMemorySourceType.arcChat,
              title: 'Arcとの会話',
              text: 'User: ${userMessage.text}\nArc: ${arcMessage.text}',
              metadata: {
                'source': 'arc_chat',
                'message_count': _messages.length,
              },
            ),
          );
      final growth = ref
          .read(arcBondGrowthServiceProvider)
          .forArcConversation();
      final award = ref.read(stardustServiceProvider).forArcConversation();
      await ref
          .read(authControllerProvider.notifier)
          .addBondScore(delta: growth.delta, reason: growth.reason);
      await ref
          .read(authControllerProvider.notifier)
          .addStardust(amount: award.amount, reason: award.reason);
      ref.invalidate(visibleArcMemoriesProvider);
    } catch (_) {
      // Chat memory is helpful context, but the visible chat should not break.
    }
  }
}

int _arcTaskStatusRank(TaskStatus status) => switch (status) {
  TaskStatus.inProgress => 0,
  TaskStatus.ready => 1,
  TaskStatus.pending => 2,
  _ => 3,
};

class _ArcMissionContextCard extends StatelessWidget {
  const _ArcMissionContextCard({
    required this.questTitle,
    required this.missionTitle,
    required this.onOpenMission,
  });

  final String questTitle;
  final String missionTitle;
  final VoidCallback? onOpenMission;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.cosmicBlue.withValues(alpha: 0.28),
      borderRadius: AppRadius.card,
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.34)),
    ),
    child: Row(
      children: [
        const Icon(Icons.route_outlined, color: AppColors.gold),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                questTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.skyBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                missionTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onOpenMission,
          tooltip: 'Missionを開く',
          icon: const Icon(Icons.open_in_new, color: AppColors.skyBlue),
        ),
      ],
    ),
  );
}

class _ArcHeader extends StatelessWidget {
  const _ArcHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Missionへ戻る',
              icon: const Icon(Icons.arrow_back),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arc',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppColors.white),
                ),
                Text(
                  '星の航海士',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.42)),
              boxShadow: AppShadows.goldGlow,
            ),
            child: const Center(child: ArcApprovedPortrait(size: 44)),
          ),
        ],
      ),
    );
  }
}

class _ArcMessageBubble extends StatelessWidget {
  const _ArcMessageBubble({
    required this.text,
    required this.fromArc,
    this.showIdentity = true,
    this.emotion = ArcEmotion.normal,
  });

  final String text;
  final bool fromArc;
  final bool showIdentity;
  final ArcEmotion emotion;

  @override
  Widget build(BuildContext context) {
    if (!fromArc) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.xxl,
          bottom: AppSpacing.lg,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.cosmicBlue.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.skyBlue.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: showIdentity
                ? ArcWidget(emotion: emotion, size: 42, showSpeechBubble: false)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showIdentity) ...[
                    Text(
                      'Arc',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.white,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcThinkingBubble extends StatelessWidget {
  const _ArcThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const _ArcMessageBubble(
      text: '少し考えている…',
      fromArc: true,
      emotion: ArcEmotion.serious,
    );
  }
}

class _ArcActionCard extends StatelessWidget {
  const _ArcActionCard({required this.actions, required this.onQuickAction});

  final List<String> actions;
  final ValueChanged<ArcQuickAction> onQuickAction;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '話してみる',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.parchment,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                _QuickAction(
                  label: actions[index],
                  onTap: () =>
                      onQuickAction(ArcQuickAction.fromLabel(actions[index])),
                ),
                if (index != actions.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ArcCommandCenterCard extends StatelessWidget {
  const _ArcCommandCenterCard({
    required this.activeQuestCount,
    required this.missionCount,
    required this.trailCount,
    required this.onOpenQuest,
    required this.onCreateQuest,
    required this.onOpenTrail,
    required this.onHorizon,
  });

  final int activeQuestCount;
  final int missionCount;
  final int trailCount;
  final VoidCallback onOpenQuest;
  final VoidCallback onCreateQuest;
  final VoidCallback onOpenTrail;
  final VoidCallback onHorizon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.54),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(
            activeQuestCount == 0
                ? Icons.explore_outlined
                : Icons.near_me_outlined,
            color: AppColors.gold,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeQuestCount == 0
                      ? 'まだQuestはありません'
                      : '$activeQuestCount件のQuestが進行中',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeQuestCount == 0
                      ? '話しながら最初の一歩を見つけよう'
                      : '$missionCount Mission ・ $trailCount Trail',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.parchment),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '航路メニュー',
            icon: const Icon(Icons.more_horiz, color: AppColors.white),
            onSelected: (value) {
              HapticFeedback.selectionClick();
              switch (value) {
                case 'quest':
                  onOpenQuest();
                  return;
                case 'create':
                  onCreateQuest();
                  return;
                case 'trail':
                  onOpenTrail();
                  return;
                case 'horizon':
                  onHorizon();
                  return;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'quest', child: Text('Questを見る')),
              PopupMenuItem(value: 'create', child: Text('新しいQuest')),
              PopupMenuItem(value: 'trail', child: Text('Trailを見る')),
              PopupMenuItem(value: 'horizon', child: Text('次の挑戦を探す')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcDetailsDisclosure extends StatelessWidget {
  const _ArcDetailsDisclosure({
    required this.events,
    required this.memoryIsEmpty,
    required this.onOpenQuest,
  });

  final List<ArcEmotionEvent> events;
  final bool memoryIsEmpty;
  final VoidCallback onOpenQuest;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: AppSpacing.sm),
        iconColor: AppColors.gold,
        collapsedIconColor: AppColors.parchment,
        title: Text(
          'Arcとの記録',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          events.isEmpty ? '会話を重ねると、ここに変化が残ります' : '最近の変化 ${events.length}件',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.parchment),
        ),
        children: [
          if (events.isNotEmpty) _ArcEmotionTimelineCard(events: events),
          if (memoryIsEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ArcEmptyState(
              title: '記憶はこれから',
              message: 'Questを進めると、大切な出来事をArcが覚えていきます。',
              actionLabel: 'Questを見る',
              icon: Icons.auto_awesome_outlined,
              onAction: onOpenQuest,
            ),
          ],
        ],
      ),
    );
  }
}

class _ArcEmotionTimelineCard extends StatelessWidget {
  const _ArcEmotionTimelineCard({required this.events});

  final List<ArcEmotionEvent> events;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.take(5).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.80),
        borderRadius: AppRadius.glassCard,
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.22)),
        boxShadow: AppShadows.glassCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arc Emotion Timeline',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Arcが旅の感情を少しずつ覚えていきます。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchment,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (visibleEvents.isEmpty)
            Row(
              children: [
                const ArcWidget(
                  emotion: ArcEmotion.normal,
                  size: 42,
                  showSpeechBubble: false,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'まだ静かな星図です。Quest、Mission、Task、Trailを進めると、Arcの表情もここに残ります。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            )
          else
            ...visibleEvents.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ArcEmotionTimelineTile(event: event),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArcEmotionTimelineTile extends StatelessWidget {
  const _ArcEmotionTimelineTile({required this.event});

  final ArcEmotionEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArcWidget(emotion: event.emotion, size: 38, showSpeechBubble: false),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      event.sourceType.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _formatTime(event.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.parchment,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                event.reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(
        color: AppColors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.midnightNavy.withValues(alpha: 0.72),
      side: BorderSide(color: AppColors.skyBlue.withValues(alpha: 0.22)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}

class _ArcInputBar extends StatelessWidget {
  const _ArcInputBar({
    required this.controller,
    required this.onSend,
    required this.onChanged,
    required this.isSending,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final bool isSending;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.midnightNavy.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.24)),
          boxShadow: AppShadows.glassCard,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Arcとの会話入力',
                hint: 'Enterで送信、AltとEnterで改行します',
                textField: true,
                child: Focus(
                  onKeyEvent: (node, event) {
                    final action = ArcChatKeyboardContract.resolve(
                      event: event,
                      isAltPressed: HardwareKeyboard.instance.isAltPressed,
                      isComposing:
                          controller.value.composing.isValid &&
                          !controller.value.composing.isCollapsed,
                      isSending: isSending,
                      text: controller.text,
                      maxLength: InputLimits.arcChatMessage,
                    );
                    switch (action) {
                      case ArcChatKeyAction.send:
                        onSend();
                        return KeyEventResult.handled;
                      case ArcChatKeyAction.insertNewline:
                        _insertNewline(controller);
                        return KeyEventResult.handled;
                      case ArcChatKeyAction.ignore:
                        return KeyEventResult.ignored;
                    }
                  },
                  child: TextField(
                    key: const ValueKey('arc-chat-input'),
                    controller: controller,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: InputLimits.arcChatMessage,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    onChanged: onChanged,
                    autocorrect: true,
                    enableSuggestions: true,
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      hintText: '話したいことを入力',
                      errorText: errorText,
                      counterText: '',
                      hintStyle: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.46),
                      ),
                      filled: false,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: isSending ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: isSending
                    ? AppColors.white.withValues(alpha: 0.08)
                    : AppColors.gold,
                foregroundColor: AppColors.deepNavy,
                minimumSize: const Size.square(44),
              ),
              icon: Icon(
                isSending ? Icons.more_horiz : Icons.arrow_upward_rounded,
              ),
              tooltip: 'メッセージを送信',
            ),
          ],
        ),
      ),
    );
  }

  void _insertNewline(TextEditingController controller) {
    final value = controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final nextText = value.text.replaceRange(
      selection.start,
      selection.end,
      '\n',
    );
    if (nextText.length > InputLimits.arcChatMessage) return;
    controller.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: selection.start + 1),
      composing: TextRange.empty,
    );
    onChanged(nextText);
  }
}

class _ArcQuestConfirmation {
  const _ArcQuestConfirmation({
    required this.quest,
    required this.guide,
    required this.missions,
  });

  final Quest quest;
  final ArcQuestGuide guide;
  final List<ArcMissionCandidate> missions;
}

class _ArcQuestCreationSheet extends ConsumerStatefulWidget {
  const _ArcQuestCreationSheet({this.suggestion});

  final ArcQuestSuggestion? suggestion;

  @override
  ConsumerState<_ArcQuestCreationSheet> createState() =>
      _ArcQuestCreationSheetState();
}

class _ArcQuestCreationSheetState
    extends ConsumerState<_ArcQuestCreationSheet> {
  final _inputController = TextEditingController();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _motivationController = TextEditingController();
  final _successConditionController = TextEditingController();
  final _wishFocusNode = FocusNode();
  final _clarificationControllers = {
    for (final type in QuestClarificationType.values)
      if (type != QuestClarificationType.deadline)
        type: TextEditingController(),
  };
  QuestDifficulty _difficulty = QuestDifficulty.normal;
  DateTime? _targetDate;
  Quest? _draftQuest;
  ArcQuestGuide? _guide;
  QuestIntentDraft? _intentDraft;
  Set<int> _selectedMissionIndexes = const {};
  int? _firstMissionIndex;
  QuestIntentResolution? _intentResolution;
  bool _isResolvingIntent = false;
  bool _isIntentConfirmed = false;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final suggestion = widget.suggestion;
    if (suggestion != null) {
      _inputController.text = suggestion.sourceInput;
      _titleController.text = suggestion.title;
      _categoryController.text = suggestion.category;
      _motivationController.text = suggestion.motivation;
      _successConditionController.text = suggestion.successCondition;
      _difficulty = suggestion.difficulty;
      final questType = classifyQuestType(suggestion.sourceInput);
      _intentResolution = QuestIntentResolution(
        originalWish: suggestion.sourceInput,
        questType: questType,
        clarity: QuestIntentClarity.clear,
        optimizedTitle: suggestion.title,
        summary: '相談内容から、最初に目指す状態を整理しました。',
        successCondition: suggestion.successCondition,
        clarificationQuestions: QuestClarificationService.resolve(
          input: suggestion.sourceInput,
          category: questType.storageKey,
          targetDate: null,
        ),
        directions: const [],
        sourceType: 'arc_chat_intent',
      );
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    _motivationController.dispose();
    _successConditionController.dispose();
    _wishFocusNode.dispose();
    for (final controller in _clarificationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<QuestClarificationQuestion> get _clarificationQuestions =>
      _intentResolution?.clarificationQuestions ??
      QuestClarificationService.resolve(
        input: _inputController.text,
        category: _categoryController.text,
        targetDate: _targetDate,
      );

  Map<QuestClarificationType, String> get _clarificationAnswers => {
    for (final entry in _clarificationControllers.entries)
      entry.key: entry.value.text.trim(),
  };

  Future<void> _resolveIntent() async {
    final input = _inputController.text.trim();
    final inputError = InputValidators.requiredText(
      input,
      fieldName: '叶えたいこと',
      maxLength: InputLimits.arcQuestIdea,
    );
    if (inputError != null) {
      setState(() => _error = inputError);
      return;
    }
    setState(() {
      _isResolvingIntent = true;
      _error = null;
    });
    try {
      final safety = await ref.read(questSafetyServiceProvider).assess(input);
      if (safety.action != QuestSafetyAction.allow) {
        if (!mounted) return;
        setState(() => _error = safety.userMessage);
        return;
      }
      final resolution = await ref
          .read(questIntentResolutionServiceProvider)
          .resolve(wish: input, targetDate: _targetDate);
      if (!mounted) return;
      setState(() {
        _intentResolution = resolution;
        _isIntentConfirmed = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isResolvingIntent = false);
      }
    }
  }

  void _acceptIntent([QuestDirection? direction]) {
    final resolution = _intentResolution;
    if (resolution == null) return;
    _titleController.text = direction?.title ?? resolution.optimizedTitle;
    _successConditionController.text =
        direction?.successCondition ?? resolution.successCondition;
    _categoryController.text = resolution.questType.displayLabel;
    setState(() => _isIntentConfirmed = true);
    _invalidateGuide();
  }

  void _consultMore() {
    setState(() {
      _isIntentConfirmed = false;
      _intentResolution = null;
      _error = null;
    });
    _wishFocusNode.requestFocus();
  }

  String get _planningDescription {
    final base = QuestClarificationService.appendAnsweredContext(
      description: _inputController.text,
      targetDate: _targetDate,
      answers: _clarificationAnswers,
    );
    final details = <String>[
      if (_motivationController.text.trim().isNotEmpty)
        '叶えたい理由: ${_motivationController.text.trim()}',
      if (_successConditionController.text.trim().isNotEmpty)
        '完了条件: ${_successConditionController.text.trim()}',
    ];
    return details.isEmpty ? base : '$base\n${details.join('\n')}';
  }

  void _invalidateGuide() {
    setState(() {
      _draftQuest = null;
      _guide = null;
      _intentDraft = null;
      _selectedMissionIndexes = const {};
      _firstMissionIndex = null;
      _error = null;
    });
  }

  void _onWishChanged() {
    setState(() {
      _intentResolution = null;
      _isIntentConfirmed = false;
    });
    _invalidateGuide();
  }

  Future<void> _generate() async {
    if (!_isIntentConfirmed) {
      setState(() => _error = 'まずArcとQuestを整理して、内容を確認してください。');
      return;
    }
    final input = _inputController.text.trim();
    final inputError = InputValidators.requiredText(
      input,
      fieldName: '叶えたいこと',
      maxLength: InputLimits.arcQuestIdea,
    );
    if (inputError != null) {
      setState(() => _error = inputError);
      return;
    }
    final inferred = inferArcQuestSuggestion(input);
    if (_titleController.text.trim().isEmpty) {
      _titleController.text =
          inferred?.title ?? input.split(RegExp(r'[\n。！？!?]')).first.trim();
    }
    if (_categoryController.text.trim().isEmpty) {
      _categoryController.text = inferred?.category ?? '冒険';
    }
    final titleError = InputValidators.requiredText(
      _titleController.text,
      fieldName: 'Quest名',
      maxLength: InputLimits.questTitle,
    );
    if (titleError != null) {
      setState(() => _error = titleError);
      return;
    }
    final intent = QuestIntentService.frame(
      outcome: _titleController.text,
      motivation: _motivationController.text,
      successCondition: _successConditionController.text,
    );
    if (intent.realityFrame == QuestRealityFrame.symbolic) {
      _titleController.text = intent.effectiveOutcome;
    }
    final safety = await ref.read(questSafetyServiceProvider).assess(input);
    if (safety.action != QuestSafetyAction.allow) {
      if (!mounted) return;
      setState(() => _error = safety.userMessage);
      unawaited(
        ref
            .read(safetySignalRecorderProvider)
            .record(
              userId: ref.read(authControllerProvider).profile?.id,
              assessment: safety,
            ),
      );
      return;
    }
    for (final question in _clarificationQuestions) {
      if (question.type == QuestClarificationType.deadline) continue;
      final answerError = InputValidators.optionalText(
        _clarificationControllers[question.type]?.text,
        fieldName: question.label,
        maxLength: 280,
      );
      if (answerError != null) {
        setState(() => _error = answerError);
        return;
      }
    }

    final estimate = EffortEstimationService.forQuest(
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
    );
    _difficulty = estimate.difficultyBand == '挑戦的'
        ? QuestDifficulty.hard
        : QuestDifficulty.normal;
    final quest = Quest(
      title: _titleController.text.trim(),
      description: _planningDescription,
      difficulty: _difficulty,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: _categoryController.text.trim().isEmpty
          ? '冒険'
          : _categoryController.text.trim(),
      targetDate: _targetDate,
      effortEstimate: estimate,
    );
    setState(() {
      _isGenerating = true;
      _error = null;
      _guide = null;
      _intentDraft = intent;
    });
    try {
      final guide = await ref
          .read(arcQuestGuideServiceProvider)
          .generate(
            quest: quest,
            planningContext: ref
                .read(planningPreferencesControllerProvider)
                .contextForPlanning,
          );
      if (!mounted) return;
      setState(() {
        _draftQuest = quest;
        _guide = guide;
        _selectedMissionIndexes = {
          for (var index = 0; index < guide.missionCandidates.length; index++)
            index,
        };
        _firstMissionIndex = guide.missionCandidates.isEmpty ? null : 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '航路を描けませんでした。入力内容を確認して、もう一度試してください。';
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _confirm() {
    final draftQuest = _draftQuest;
    final guide = _guide;
    if (draftQuest == null || guide == null) return;
    const contract = MissionContractService();
    final usedTitles = <String>{};
    final missions = <ArcMissionCandidate>[];
    final orderedIndexes = _selectedMissionIndexes.toList()
      ..sort((a, b) {
        if (a == _firstMissionIndex) return -1;
        if (b == _firstMissionIndex) return 1;
        return a.compareTo(b);
      });
    for (final index in orderedIndexes) {
      final candidate = guide.missionCandidates[index];
      final title = contract.distinctGeneratedTitle(
        questTitle: _titleController.text,
        missionTitle: candidate.title,
        usedTitles: usedTitles,
      );
      if (title == null) continue;
      missions.add(candidate.copyWith(title: title));
    }
    if (missions.isEmpty) {
      setState(() => _error = '最初に進めるMissionを1つ以上選んでください。');
      return;
    }
    final quest = draftQuest.copyWith(
      title: _titleController.text.trim(),
      description: _planningDescription,
      category: _categoryController.text.trim().isEmpty
          ? '冒険'
          : _categoryController.text.trim(),
      difficulty: _difficulty,
      targetDate: _targetDate,
      effortEstimate: guide.effortEstimate ?? draftQuest.effortEstimate,
      evaluation: guide.questEvaluation ?? draftQuest.evaluation,
      dna: guide.questDna ?? draftQuest.dna,
      understanding: guide.questUnderstanding ?? draftQuest.understanding,
      planQuality: guide.planQuality ?? draftQuest.planQuality,
    );
    Navigator.of(context).pop(
      _ArcQuestConfirmation(quest: quest, guide: guide, missions: missions),
    );
  }

  Widget _buildIntentCard(QuestIntentResolution resolution) {
    final directions = resolution.directions;
    return Container(
      key: const Key('arc-quest-intent-summary'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cosmicBlue.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.warmGold),
              SizedBox(width: AppSpacing.sm),
              Text(
                'ArcがまとめたQuest',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            resolution.optimizedTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (resolution.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              resolution.summary,
              style: const TextStyle(color: AppColors.parchment),
            ),
          ],
          if (directions.length >= 2) ...[
            const SizedBox(height: AppSpacing.lg),
            for (final direction in directions) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isGenerating
                      ? null
                      : () => _acceptIntent(direction),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(direction.title),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          if (resolution.clarificationQuestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '進む前に${resolution.clarificationQuestions.length}つだけ確認します。',
              style: const TextStyle(color: AppColors.parchment),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isGenerating ? null : _acceptIntent,
                  child: const Text('このQuestで進む'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextButton(
                  onPressed: _isGenerating ? null : _consultMore,
                  child: const Text('Arcともう少し相談する'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Material(
          color: AppColors.midnightNavy,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppFieldSizes.questFormMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    Row(
                      children: [
                        const ArcWidget(
                          emotion: ArcEmotion.support,
                          size: 72,
                          showSpeechBubble: false,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '相談から航路を描く',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const Text(
                                'Questと最初のMissionを、保存前に確認できます。',
                                style: TextStyle(color: AppColors.parchment),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          color: AppColors.white,
                          tooltip: '閉じる',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    QuestraFieldLabel(
                      label: 'Arcに相談すること',
                      foregroundColor: AppColors.white,
                      helper: 'やりたいこと、今の状況、迷っている点をそのまま書けます。',
                      required: true,
                      child: TextField(
                        controller: _inputController,
                        focusNode: _wishFocusNode,
                        minLines: 3,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enabled: !_isGenerating && !_isResolvingIntent,
                        maxLength: InputLimits.arcQuestIdea,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        style: const TextStyle(color: AppColors.deepNavy),
                        decoration: const InputDecoration(
                          hintText: '例: 来年シンガポールへ行きたい。予算や準備の順番が分からない。',
                        ),
                        onChanged: (_) => _onWishChanged(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _isGenerating || _isResolvingIntent
                            ? null
                            : _resolveIntent,
                        icon: _isResolvingIntent
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Arcと一緒にQuestを整理'),
                      ),
                    ),
                    if (_intentResolution case final resolution?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _buildIntentCard(resolution),
                    ],
                    if (_isIntentConfirmed) ...[
                      const SizedBox(height: AppSpacing.md),
                      QuestraFieldLabel(
                        label: 'Questの名前',
                        foregroundColor: AppColors.white,
                        helper: '空欄ならArcが相談内容から提案します。',
                        child: TextField(
                          key: const Key('arc-quest-title-field'),
                          controller: _titleController,
                          enabled: !_isGenerating,
                          maxLength: InputLimits.questTitle,
                          textInputAction: TextInputAction.next,
                          minLines: 1,
                          maxLines: 2,
                          style: const TextStyle(color: AppColors.deepNavy),
                          decoration: const InputDecoration(
                            hintText: '例: シンガポールへの旅を実現する',
                            constraints: BoxConstraints(
                              minHeight: AppFieldSizes.mediumInput,
                            ),
                          ),
                          onChanged: (_) => _invalidateGuide(),
                        ),
                      ),
                      const SizedBox(height: AppFieldSizes.fieldGap),
                      QuestraFieldLabel(
                        label: '叶えたい理由',
                        foregroundColor: AppColors.white,
                        helper: 'Arcとの相談から提案できます。自分の言葉に書き換えても大丈夫です。',
                        child: TextField(
                          key: const Key('arc-quest-motivation-field'),
                          controller: _motivationController,
                          enabled: !_isGenerating,
                          minLines: 3,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLength: 280,
                          style: const TextStyle(color: AppColors.deepNavy),
                          decoration: const InputDecoration(
                            hintText:
                                'なぜこのQuestを叶えたいと思ったのか、きっかけや実現したい未来を書いてみよう',
                            constraints: BoxConstraints(
                              minHeight: AppFieldSizes.longInput,
                            ),
                          ),
                          onChanged: (_) => _invalidateGuide(),
                        ),
                      ),
                      const SizedBox(height: AppFieldSizes.fieldGap),
                      QuestraFieldLabel(
                        label: '達成したと分かる状態',
                        foregroundColor: AppColors.white,
                        helper: '目で確認できる状態にすると、航路が明確になります。',
                        child: TextField(
                          key: const Key('arc-quest-success-condition-field'),
                          controller: _successConditionController,
                          enabled: !_isGenerating,
                          minLines: 3,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLength: 280,
                          style: const TextStyle(color: AppColors.deepNavy),
                          decoration: const InputDecoration(
                            hintText: 'どんな状態になったら、このQuestを達成したと言えそう？',
                            constraints: BoxConstraints(
                              minHeight: AppFieldSizes.longInput,
                            ),
                          ),
                          onChanged: (_) => _invalidateGuide(),
                        ),
                      ),
                      if (_intentDraft?.realityFrame ==
                          QuestRealityFrame.symbolic) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'その願いに込めた意味を、実際に進められるQuestへ言い換えました。',
                          style: const TextStyle(color: AppColors.warmGold),
                        ),
                      ],
                      const SizedBox(height: AppFieldSizes.fieldGap),
                      _ArcQuestAnalysisPanel(
                        guide: guide,
                        inferredCategory: _categoryController.text,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ArcClarificationPanel(
                        questions: _clarificationQuestions,
                        controllers: _clarificationControllers,
                        targetDate: _targetDate,
                        enabled: !_isGenerating,
                        onDatePressed: _pickTargetDate,
                        onAnswerChanged: _invalidateGuide,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: _isGenerating ? null : _generate,
                        icon: _isGenerating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(guide == null ? 'Arcと航路を描く' : '航路を描き直す'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.warmGold),
                      ),
                    ],
                    if (guide != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _ArcGuidePreviewBlock(
                        title: 'Questの輪郭',
                        body: guide.summary,
                      ),
                      if (guide.effortEstimate case final estimate?) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ArcGuidePreviewBlock(
                          title: 'Arcの見積もり',
                          body:
                              '${estimate.difficultyBand} / 実作業 ${estimate.activeEffortLabel} / 期間 ${estimate.calendarLabel}\n${estimate.rationale}',
                        ),
                        if (_targetDate case final targetMonth?) ...[
                          const SizedBox(height: AppSpacing.md),
                          _ArcGuidePreviewBlock(
                            title: '希望月との見通し',
                            body: QuestFeasibilityService.assess(
                              now: DateTime.now(),
                              requestedMonth: targetMonth,
                              estimate: estimate,
                            ).message,
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _ArcGuidePreviewBlock(
                        title: '目的地までの航路',
                        body: guide.path,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ArcGuidePreviewBlock(
                        title: '気をつけること',
                        body: guide.cautions,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        '最初のMission',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...List.generate(guide.missionCandidates.length, (index) {
                        final mission = guide.missionCandidates[index];
                        return CheckboxListTile(
                          value: _selectedMissionIndexes.contains(index),
                          onChanged: (selected) {
                            setState(() {
                              final next = {..._selectedMissionIndexes};
                              if (selected == true) {
                                next.add(index);
                                _firstMissionIndex ??= index;
                              } else {
                                next.remove(index);
                                if (_firstMissionIndex == index) {
                                  _firstMissionIndex = next.isEmpty
                                      ? null
                                      : next.reduce((a, b) => a < b ? a : b);
                                }
                              }
                              _selectedMissionIndexes = next;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.gold,
                          title: Text(
                            mission.title,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            mission.description,
                            style: const TextStyle(color: AppColors.parchment),
                          ),
                          secondary: IconButton(
                            onPressed: _selectedMissionIndexes.contains(index)
                                ? () =>
                                      setState(() => _firstMissionIndex = index)
                                : null,
                            icon: Icon(
                              _firstMissionIndex == index
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                            ),
                            color: AppColors.gold,
                            tooltip: '最初の一歩にする',
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.lg),
                      _ArcPlanningContextPreview(
                        lines: QuestClarificationService.answerLines(
                          targetDate: _targetDate,
                          answers: _clarificationAnswers,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _selectedMissionIndexes.isEmpty
                            ? null
                            : _confirm,
                        icon: const Icon(Icons.rocket_launch_outlined),
                        label: Text(
                          'Questと${_selectedMissionIndexes.length}件のMissionを始める',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showYearMonthPicker(
      context: context,
      initialValue: _targetDate ?? DateTime(now.year, now.month + 3),
    );
    if (picked != null && mounted) {
      _targetDate = picked;
      _invalidateGuide();
    }
  }
}

class _ArcQuestAnalysisPanel extends StatelessWidget {
  const _ArcQuestAnalysisPanel({
    required this.guide,
    required this.inferredCategory,
  });

  final ArcQuestGuide? guide;
  final String inferredCategory;

  @override
  Widget build(BuildContext context) {
    final theme = guide?.questDna?.valueFor('theme');
    final evaluation = guide?.questEvaluation;
    final category = theme?.trim().isNotEmpty == true
        ? theme!
        : inferredCategory.trim().isEmpty
        ? '航路作成後に提案'
        : inferredCategory.trim();
    return Semantics(
      container: true,
      label: 'Arcによる航路分析',
      readOnly: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.cosmicBlue.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: AppColors.gold),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Arcによる航路分析',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _ArcAnalysisBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                _ArcAnalysisValue(label: 'テーマ', value: category),
                _ArcAnalysisValue(
                  label: '難易度',
                  value: evaluation?.difficultyStars ?? '航路作成後に評価',
                ),
                _ArcAnalysisValue(
                  label: '予想期間',
                  value: evaluation?.durationLabel ?? '航路作成後に評価',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcAnalysisBadge extends StatelessWidget {
  const _ArcAnalysisBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Arcが分析',
        style: TextStyle(
          color: AppColors.warmGold,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ArcAnalysisValue extends StatelessWidget {
  const _ArcAnalysisValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.parchment, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcClarificationPanel extends StatelessWidget {
  const _ArcClarificationPanel({
    required this.questions,
    required this.controllers,
    required this.targetDate,
    required this.enabled,
    required this.onDatePressed,
    required this.onAnswerChanged,
  });

  final List<QuestClarificationQuestion> questions;
  final Map<QuestClarificationType, TextEditingController> controllers;
  final DateTime? targetDate;
  final bool enabled;
  final VoidCallback onDatePressed;
  final VoidCallback onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cosmicBlue.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, color: AppColors.gold, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '航路を整える確認',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${questions.length}/3',
                style: const TextStyle(color: AppColors.parchment),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '分からない項目は空欄のまま進められます。',
            style: TextStyle(color: AppColors.parchment),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < questions.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.md),
            _buildQuestion(questions[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestion(QuestClarificationQuestion question) {
    if (question.type == QuestClarificationType.deadline) {
      return QuestraFieldLabel(
        label: question.label,
        foregroundColor: AppColors.white,
        helper: question.hint,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: enabled ? onDatePressed : null,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              targetDate == null
                  ? 'YYYY / MM を選ぶ'
                  : DateFormat('yyyy / MM').format(targetDate!),
            ),
          ),
        ),
      );
    }
    return QuestraFieldLabel(
      label: question.label,
      foregroundColor: AppColors.white,
      child: TextField(
        controller: controllers[question.type],
        enabled: enabled,
        maxLength: 280,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.next,
        style: const TextStyle(color: AppColors.deepNavy),
        decoration: InputDecoration(hintText: question.hint),
        onChanged: (_) => onAnswerChanged(),
      ),
    );
  }
}

class _ArcPlanningContextPreview extends StatelessWidget {
  const _ArcPlanningContextPreview({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return _ArcGuidePreviewBlock(
      title: '保存する航路条件',
      body: lines.isEmpty
          ? '追加条件なし。未回答の項目は前提に含めません。'
          : lines.map((line) => '・$line').join('\n'),
    );
  }
}

class _ArcQuestChangesCard extends StatelessWidget {
  const _ArcQuestChangesCard({
    required this.proposals,
    required this.quests,
    required this.missions,
    required this.onApply,
    required this.onLater,
    required this.onReject,
    required this.onOpenQuest,
  });

  final List<ArcQuestChangeProposal> proposals;
  final List<Quest> quests;
  final List<Mission> missions;
  final ValueChanged<ArcQuestChangeProposal> onApply;
  final ValueChanged<ArcQuestChangeProposal> onLater;
  final ValueChanged<ArcQuestChangeProposal> onReject;
  final ValueChanged<ArcQuestChangeProposal> onOpenQuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cosmicBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high_outlined, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'この情報をQuestへ反映できるよ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < proposals.length; index++) ...[
            if (index > 0)
              Divider(color: AppColors.skyBlue.withValues(alpha: 0.2)),
            _ArcQuestChangeRow(
              proposal: proposals[index],
              questTitle:
                  quests
                      .where((quest) => quest.id == proposals[index].questId)
                      .firstOrNull
                      ?.title ??
                  'Quest',
              missionTitle: missions
                  .where(
                    (mission) => mission.id == proposals[index].targetMissionId,
                  )
                  .firstOrNull
                  ?.title,
              onApply: () => onApply(proposals[index]),
              onLater: () => onLater(proposals[index]),
              onReject: () => onReject(proposals[index]),
              onOpenQuest: () => onOpenQuest(proposals[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArcQuestChangeRow extends StatelessWidget {
  const _ArcQuestChangeRow({
    required this.proposal,
    required this.questTitle,
    required this.onApply,
    required this.onLater,
    required this.onReject,
    required this.onOpenQuest,
    this.missionTitle,
  });

  final ArcQuestChangeProposal proposal;
  final String questTitle;
  final String? missionTitle;
  final VoidCallback onApply;
  final VoidCallback onLater;
  final VoidCallback onReject;
  final VoidCallback onOpenQuest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          proposal.actionLabel,
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          proposal.title,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          missionTitle == null
              ? 'Quest: $questTitle'
              : 'Mission: $missionTitle',
          style: const TextStyle(color: AppColors.parchment),
        ),
        if (proposal.rationale.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            proposal.rationale,
            style: const TextStyle(color: AppColors.parchment),
          ),
        ],
        if (proposal.proposedTargetDate case final date?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '提案期限: ${DateFormat('yyyy/MM').format(date)}',
            style: const TextStyle(color: AppColors.white),
          ),
        ],
        if (proposal.groundingSources.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '参照元 ${proposal.groundingSources.length}件',
            style: const TextStyle(color: AppColors.skyBlue, fontSize: 12),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: proposal.canApplyDirectly ? onApply : onOpenQuest,
              icon: Icon(
                proposal.canApplyDirectly
                    ? Icons.check_circle_outline
                    : Icons.compare_arrows,
              ),
              label: Text(proposal.canApplyDirectly ? '反映する' : 'Questで差分を確認'),
            ),
            TextButton(onPressed: onLater, child: const Text('あとで')),
            IconButton(
              onPressed: onReject,
              icon: const Icon(Icons.close),
              color: AppColors.parchment,
              tooltip: '追加しない',
            ),
          ],
        ),
      ],
    );
  }
}

class _ArcClarificationCard extends StatelessWidget {
  const _ArcClarificationCard({required this.session});

  final ArcQuestClarificationSession session;

  @override
  Widget build(BuildContext context) {
    final question = session.currentQuestion;
    if (question == null) return const SizedBox.shrink();
    return QuestraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.gold),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Questを整理中 ${session.answeredCount + 1}/${session.questions.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  question.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (question.hint.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(question.hint),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcQuestSuggestionCard extends StatelessWidget {
  const _ArcQuestSuggestionCard({
    required this.suggestion,
    required this.onPlan,
    required this.onDismiss,
  });

  final ArcQuestSuggestion suggestion;
  final VoidCallback onPlan;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cosmicBlue.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Questの種を見つけました',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                color: AppColors.parchment,
                tooltip: '候補を閉じる',
              ),
            ],
          ),
          Text(
            suggestion.title,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onPlan,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('この航路をQuestにする'),
          ),
        ],
      ),
    );
  }
}

class _ArcGuidePreviewBlock extends StatelessWidget {
  const _ArcGuidePreviewBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.deepNavy.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: const TextStyle(color: AppColors.parchment)),
        ],
      ),
    );
  }
}

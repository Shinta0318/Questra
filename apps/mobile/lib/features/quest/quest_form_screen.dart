import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../core/estimation/effort_estimation_service.dart';
import '../../core/theme/app_field_sizes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/validation/input_validators.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
import '../../widgets/forms/questra_field_label.dart';
import '../../widgets/forms/year_month_picker.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/layout/questra_responsive_list_view.dart';
import '../../widgets/questra_primary_button.dart';
import 'arc_quest_guide_controller.dart';
import 'quest_controller.dart';
import 'quest_guide_controller.dart';
import 'quest_model.dart';
import 'quest_providers.dart';
import 'quest_template_model.dart';
import 'quest_understanding.dart';

const _questReflectionLimit = 280;

class QuestFormScreen extends ConsumerStatefulWidget {
  const QuestFormScreen({this.questId, super.key});

  final String? questId;

  @override
  ConsumerState<QuestFormScreen> createState() => _QuestFormScreenState();
}

class _QuestFormScreenState extends ConsumerState<QuestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _successConditionController = TextEditingController();
  final _categoryController = TextEditingController();
  QuestDifficulty _difficulty = QuestDifficulty.normal;
  QuestStatus _status = QuestStatus.active;
  QuestVisibility _visibility = QuestVisibility.private;
  DateTime? _targetDate;
  QuestTemplate? _selectedTemplate;
  Quest? _loadedQuest;
  bool _didLoad = false;

  bool get _isEditing => widget.questId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _successConditionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loadInitialValues();
    final templates = ref.watch(questTemplateLibraryProvider).templates;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Questを編集' : 'Questを作成')),
      body: SafeArea(
        child: QuestraResponsiveListView(
          maxContentWidth: AppFieldSizes.questFormMaxWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.xl,
          ),
          children: [
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: QuestraCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArcWidget(
                      emotion: _isEditing
                          ? ArcEmotion.serious
                          : ArcEmotion.excited,
                      size: 72,
                      message: _isEditing
                          ? '航路を整えよう。Questは進みながら磨いていけるよ。'
                          : '叶えたい景色を一文で置けば、Arcが最初のMission候補まで一緒に探します。',
                    ),
                    const SizedBox(height: 16),
                    if (!_isEditing) ...[
                      _ArcPlanningShortcut(
                        onTap: () => context.go(AppRoutes.arc),
                      ),
                      const SizedBox(height: 16),
                      const _FirstQuestGuideCard(),
                      const SizedBox(height: 16),
                    ],
                    if (!_isEditing) ...[
                      _TemplatePicker(
                        templates: templates,
                        selectedTemplate: _selectedTemplate,
                        onSelected: _applyTemplate,
                      ),
                      const SizedBox(height: 16),
                    ],
                    QuestraFieldLabel(
                      label: 'Questの名前',
                      helper: '叶えたい状態を一文にします。あとから変更できます。',
                      required: true,
                      trailing: const _FieldOwnerBadge(label: 'あなたが決める'),
                      child: TextFormField(
                        key: const Key('quest-title-field'),
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: '例: 富士山に登る',
                          constraints: BoxConstraints(
                            minHeight: AppFieldSizes.mediumInput,
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        minLines: 1,
                        maxLines: 2,
                        maxLength: InputLimits.questTitle,
                        validator: (value) => InputValidators.requiredText(
                          value,
                          fieldName: 'Quest名',
                          maxLength: InputLimits.questTitle,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: AppFieldSizes.fieldGap),
                    QuestraFieldLabel(
                      label: '叶えたい理由',
                      helper: 'Arcとの相談内容から提案できます。自分で書き換えても大丈夫です。',
                      trailing: const _FieldOwnerBadge(label: 'あなたが決める'),
                      child: TextFormField(
                        key: const Key('quest-motivation-field'),
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          hintText: 'なぜこのQuestを叶えたいと思ったのか、きっかけや実現したい未来を書いてみよう',
                          constraints: BoxConstraints(
                            minHeight: AppFieldSizes.longInput,
                          ),
                        ),
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: _questReflectionLimit,
                        validator: (value) => InputValidators.optionalText(
                          value,
                          fieldName: '叶えたい理由',
                          maxLength: _questReflectionLimit,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppFieldSizes.fieldGap),
                    QuestraFieldLabel(
                      label: '達成したと分かる状態',
                      helper: 'Arcが航路を組み立てられるよう、目で確かめられる成功条件にします。',
                      trailing: const _FieldOwnerBadge(label: 'あなたが決める'),
                      child: TextFormField(
                        key: const Key('quest-success-condition-field'),
                        controller: _successConditionController,
                        decoration: const InputDecoration(
                          hintText: 'どんな状態になったら、このQuestを達成したと言えそう？',
                          constraints: BoxConstraints(
                            minHeight: AppFieldSizes.longInput,
                          ),
                        ),
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: _questReflectionLimit,
                        validator: (value) => InputValidators.optionalText(
                          value,
                          fieldName: '達成したと分かる状態',
                          maxLength: _questReflectionLimit,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppFieldSizes.fieldGap),
                    QuestraFieldLabel(
                      label: 'いつ頃までに叶えたい？',
                      helper: '希望する年月です。Arcが現実的な達成予測と比べて案内します。',
                      trailing: const _FieldOwnerBadge(label: 'あなたが決める'),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('quest-target-month-button'),
                          onPressed: _pickTargetDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            _targetDate == null
                                ? 'YYYY / MM を選ぶ'
                                : DateFormat('yyyy / MM').format(_targetDate!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppFieldSizes.fieldGap),
                    _ArcAnalysisPreview(
                      category: _categoryController.text,
                      quest: _loadedQuest,
                    ),
                    const SizedBox(height: AppFieldSizes.fieldGap),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: const Text('保存・公開設定'),
                      subtitle: Text('${_status.label}・${_visibility.label}'),
                      children: [
                        _EnumDropdown<QuestStatus>(
                          label: '状態',
                          value: _status,
                          values: QuestStatus.values,
                          onChanged: (value) => setState(() => _status = value),
                        ),
                        const SizedBox(height: 12),
                        _EnumDropdown<QuestVisibility>(
                          label: '公開範囲',
                          value: _visibility,
                          values: QuestVisibility.values,
                          onChanged: (value) =>
                              setState(() => _visibility = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_selectedTemplate != null) ...[
                      _TemplateSuggestionPreview(template: _selectedTemplate!),
                      const SizedBox(height: 20),
                    ],
                    QuestraPrimaryButton(
                      label: _isEditing ? '変更を保存' : '保存して航路を描く',
                      onPressed: _save,
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 8),
                      const Text('保存後、Arcが道筋と最初のMission候補を描きます。'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loadInitialValues() {
    if (_didLoad || widget.questId == null) {
      return;
    }
    _didLoad = true;
    final quest = ref
        .read(questControllerProvider.notifier)
        .findById(widget.questId!);
    if (quest == null) {
      return;
    }
    _titleController.text = quest.title;
    _descriptionController.text =
        quest.understanding?.motivation.isNotEmpty == true
        ? quest.understanding!.motivation
        : quest.description;
    _successConditionController.text =
        quest.understanding?.successEvidence ?? '';
    _categoryController.text = quest.category;
    _difficulty = quest.difficulty;
    _status = quest.status;
    _visibility = quest.visibility;
    _targetDate = quest.targetDate;
    _loadedQuest = quest;
  }

  void _applyTemplate(QuestTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _titleController.text = template.title;
      _descriptionController.text = template.description;
      _successConditionController.text = '';
      _categoryController.text = template.category;
      _difficulty = template.difficulty;
      _status = QuestStatus.active;
      _visibility = QuestVisibility.private;
    });
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showYearMonthPicker(
      context: context,
      initialValue: _targetDate ?? now,
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim().isEmpty
        ? _selectedTemplate?.category ?? '冒険'
        : _categoryController.text.trim();
    final estimate = EffortEstimationService.forQuest(
      title: title,
      category: category,
    );
    _difficulty = estimate.difficultyBand == '挑戦的'
        ? QuestDifficulty.hard
        : QuestDifficulty.normal;

    final controller = ref.read(questControllerProvider.notifier);
    if (_isEditing) {
      final current = controller.findById(widget.questId!);
      if (current == null) {
        context.go(AppRoutes.quest);
        return;
      }
      controller.update(
        current.copyWith(
          title: title,
          description: _descriptionController.text.trim(),
          difficulty: _difficulty,
          status: _status,
          visibility: _visibility,
          category: _categoryController.text.trim().isEmpty
              ? current.category
              : _categoryController.text.trim(),
          targetDate: _targetDate,
          effortEstimate: estimate,
          understanding: _questUnderstanding(current),
          clearTargetDate: _targetDate == null,
        ),
      );
      context.go('${AppRoutes.quest}/${current.id}');
      return;
    }

    final quest = Quest(
      title: title,
      description: _descriptionController.text.trim(),
      difficulty: _difficulty,
      status: _status,
      visibility: _visibility,
      category: category,
      targetDate: _targetDate,
      effortEstimate: estimate,
      understanding: _questUnderstanding(),
    );
    controller.add(quest);
    ref.read(questGuideControllerProvider.notifier).generateForQuest(quest);
    unawaited(
      ref
          .read(arcQuestGuideControllerProvider.notifier)
          .generateForQuest(quest),
    );
    context.go('${AppRoutes.quest}/${quest.id}');
  }

  QuestUnderstanding _questUnderstanding([Quest? current]) {
    final previous = current?.understanding;
    return QuestUnderstanding(
      originalWish: previous?.originalWish ?? _titleController.text.trim(),
      questOutcome: _titleController.text.trim(),
      successEvidence: _successConditionController.text.trim(),
      motivation: _descriptionController.text.trim(),
      currentState: previous?.currentState ?? '',
      constraints: previous?.constraints ?? const [],
      knownResources: previous?.knownResources ?? const [],
      unknowns: previous?.unknowns ?? const [],
      planningRisks: previous?.planningRisks ?? const [],
      planningMode: previous?.planningMode ?? QuestPlanningMode.project,
      assumptions: previous?.assumptions ?? const [],
      version: (previous?.version ?? 0) + 1,
    );
  }
}

class _FieldOwnerBadge extends StatelessWidget {
  const _FieldOwnerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ArcAnalysisPreview extends StatelessWidget {
  const _ArcAnalysisPreview({required this.category, required this.quest});

  final String category;
  final Quest? quest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final evaluation = quest?.evaluation;
    final resolvedCategory =
        quest?.dna?.valueFor('theme') ??
        (category.trim().isEmpty ? '保存後に提案' : category.trim());
    return Semantics(
      container: true,
      label: 'Arcによる航路分析',
      readOnly: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Arcによる航路分析',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const _FieldOwnerBadge(label: 'Arcが分析'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                _AnalysisValue(label: 'テーマ', value: resolvedCategory),
                _AnalysisValue(
                  label: '難易度',
                  value: evaluation?.difficultyStars ?? '保存後に評価',
                ),
                _AnalysisValue(
                  label: '予想期間',
                  value: evaluation?.durationLabel ?? '保存後に評価',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisValue extends StatelessWidget {
  const _AnalysisValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FirstQuestGuideCard extends StatelessWidget {
  const _FirstQuestGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('迷ったら、今見たい景色から', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('Quest名だけでも始められます。理由や期限は、進みながら整えられます。'),
        ],
      ),
    );
  }
}

class _ArcPlanningShortcut extends StatelessWidget {
  const _ArcPlanningShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.22),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arcと話しながら決める',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text('まだ言葉になっていなくても、会話から航路を描けます。'),
                ],
              ),
            ),
            Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.templates,
    required this.selectedTemplate,
    required this.onSelected,
  });

  final List<QuestTemplate> templates;
  final QuestTemplate? selectedTemplate;
  final ValueChanged<QuestTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('テンプレートから始める', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: templates.map((template) {
              final selected = selectedTemplate?.id == template.id;
              return ChoiceChip(
                selected: selected,
                label: Text(template.category),
                avatar: Icon(
                  _templateIcon(template.id),
                  size: 18,
                  color: selected ? colorScheme.onPrimary : colorScheme.primary,
                ),
                onSelected: (_) => onSelected(template),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TemplateSuggestionPreview extends StatelessWidget {
  const _TemplateSuggestionPreview({required this.template});

  final QuestTemplate template;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('候補Milestone', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...template.milestones.map(
            (milestone) => _TemplateSuggestionRow(
              icon: Icons.flag_outlined,
              title: milestone.title,
              description: milestone.description,
            ),
          ),
          const SizedBox(height: 10),
          Text('候補Mission', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...template.missions.map(
            (mission) => _TemplateSuggestionRow(
              icon: Icons.check_circle_outline,
              title: mission.title,
              description: mission.description,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateSuggestionRow extends StatelessWidget {
  const _TemplateSuggestionRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnumDropdown<T extends Enum> extends StatelessWidget {
  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return QuestraFieldLabel(
      label: label,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: const InputDecoration(),
        items: values
            .map(
              (item) =>
                  DropdownMenuItem<T>(value: item, child: Text(item.label)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

IconData _templateIcon(String id) {
  return switch (id) {
    'travel' => Icons.flight_takeoff_outlined,
    'health' => Icons.favorite_outline,
    'learning' => Icons.school_outlined,
    'family' => Icons.volunteer_activism_outlined,
    'work' => Icons.work_outline,
    'challenge' => Icons.rocket_launch_outlined,
    _ => Icons.explore_outlined,
  };
}

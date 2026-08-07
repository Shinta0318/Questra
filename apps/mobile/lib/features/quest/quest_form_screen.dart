import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../core/estimation/effort_estimation_service.dart';
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
  final _categoryController = TextEditingController();
  QuestDifficulty _difficulty = QuestDifficulty.normal;
  QuestStatus _status = QuestStatus.active;
  QuestVisibility _visibility = QuestVisibility.private;
  DateTime? _targetDate;
  QuestTemplate? _selectedTemplate;
  bool _didLoad = false;

  bool get _isEditing => widget.questId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
          maxContentWidth: 720,
          padding: const EdgeInsets.all(20),
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
                      child: TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: '例: 富士山に登る',
                        ),
                        textInputAction: TextInputAction.next,
                        maxLength: InputLimits.questTitle,
                        validator: (value) => InputValidators.requiredText(
                          value,
                          fieldName: 'Quest名',
                          maxLength: InputLimits.questTitle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    QuestraFieldLabel(
                      label: '叶えたい理由・相談内容',
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          hintText: 'なぜ大切なのか、今の状況や迷いを自由に書けます',
                        ),
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: InputLimits.questDescription,
                        validator: (value) => InputValidators.optionalText(
                          value,
                          fieldName: '叶えたい理由・相談内容',
                          maxLength: InputLimits.questDescription,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    QuestraFieldLabel(
                      label: 'テーマ',
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          hintText: '例: 旅行、学習、健康',
                        ),
                        textInputAction: TextInputAction.done,
                        maxLength: InputLimits.category,
                        validator: (value) => InputValidators.optionalText(
                          value,
                          fieldName: 'テーマ',
                          maxLength: InputLimits.category,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CategoryPicker(
                      value: _categoryController.text,
                      onSelected: (value) =>
                          setState(() => _categoryController.text = value),
                    ),
                    const SizedBox(height: 12),
                    QuestraFieldLabel(
                      label: '難しさ',
                      helper: 'ArcがQuestとMissionの内容から見積もります。',
                      child: const ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        leading: Icon(Icons.auto_awesome_outlined),
                        title: Text('保存後にArcが表示します'),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    QuestraFieldLabel(
                      label: 'いつまでに叶えたい？',
                      helper: '未定でも保存できます。',
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _pickTargetDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _targetDate == null
                                ? '期限を選ぶ'
                                : DateFormat('yyyy年M月d日').format(_targetDate!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
    _descriptionController.text = quest.description;
    _categoryController.text = quest.category;
    _difficulty = quest.difficulty;
    _status = quest.status;
    _visibility = quest.visibility;
    _targetDate = quest.targetDate;
  }

  void _applyTemplate(QuestTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _titleController.text = template.title;
      _descriptionController.text = template.description;
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

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.value, required this.onSelected});

  static const values = ['旅行', '学習', '健康', '仕事', '家族', '挑戦'];

  final String value;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in values)
          ChoiceChip(
            label: Text(category),
            selected: value == category,
            onSelected: (_) => onSelected(category),
          ),
      ],
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

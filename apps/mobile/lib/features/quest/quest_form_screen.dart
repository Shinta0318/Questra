import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_widget.dart';
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  QuestDifficulty _difficulty = QuestDifficulty.normal;
  QuestStatus _status = QuestStatus.draft;
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
            QuestraCard(
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
                        : 'このQuestは大切な星になりそうだね。一緒に航路を描こう。',
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing) ...[
                    _TemplatePicker(
                      templates: templates,
                      selectedTemplate: _selectedTemplate,
                      onSelected: _applyTemplate,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Quest名'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: '叶えたい理由・背景'),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'カテゴリ'),
                  ),
                  const SizedBox(height: 12),
                  _EnumDropdown<QuestDifficulty>(
                    label: '難しさ',
                    value: _difficulty,
                    values: QuestDifficulty.values,
                    onChanged: (value) => setState(() => _difficulty = value),
                  ),
                  const SizedBox(height: 12),
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
                    onChanged: (value) => setState(() => _visibility = value),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickTargetDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _targetDate == null
                          ? '目標日'
                          : DateFormat.yMMMd().format(_targetDate!),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedTemplate != null) ...[
                    _TemplateSuggestionPreview(template: _selectedTemplate!),
                    const SizedBox(height: 20),
                  ],
                  QuestraPrimaryButton(label: 'Questを保存', onPressed: _save),
                ],
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
      _status = QuestStatus.draft;
      _visibility = QuestVisibility.private;
    });
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _targetDate ?? now,
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

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
      category: _categoryController.text.trim().isEmpty
          ? _selectedTemplate?.category ?? '冒険'
          : _categoryController.text.trim(),
      targetDate: _targetDate,
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
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(value: item, child: Text(item.label)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
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

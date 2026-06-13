import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/questra_card.dart';
import '../../widgets/questra_primary_button.dart';
import 'quest_controller.dart';
import 'quest_guide_controller.dart';
import 'quest_model.dart';

class QuestFormScreen extends ConsumerStatefulWidget {
  const QuestFormScreen({this.questId, super.key});

  final String? questId;

  @override
  ConsumerState<QuestFormScreen> createState() => _QuestFormScreenState();
}

class _QuestFormScreenState extends ConsumerState<QuestFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  QuestDifficulty _difficulty = QuestDifficulty.normal;
  QuestStatus _status = QuestStatus.draft;
  QuestVisibility _visibility = QuestVisibility.private;
  DateTime? _targetDate;
  bool _didLoad = false;

  bool get _isEditing => widget.questId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loadInitialValues();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Quest' : 'Create Quest')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            QuestraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  _EnumDropdown<QuestDifficulty>(
                    label: 'Difficulty',
                    value: _difficulty,
                    values: QuestDifficulty.values,
                    onChanged: (value) => setState(() => _difficulty = value),
                  ),
                  const SizedBox(height: 12),
                  _EnumDropdown<QuestStatus>(
                    label: 'Status',
                    value: _status,
                    values: QuestStatus.values,
                    onChanged: (value) => setState(() => _status = value),
                  ),
                  const SizedBox(height: 12),
                  _EnumDropdown<QuestVisibility>(
                    label: 'Visibility',
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
                          ? 'Target date'
                          : DateFormat.yMMMd().format(_targetDate!),
                    ),
                  ),
                  const SizedBox(height: 20),
                  QuestraPrimaryButton(label: 'Save Quest', onPressed: _save),
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
    _difficulty = quest.difficulty;
    _status = quest.status;
    _visibility = quest.visibility;
    _targetDate = quest.targetDate;
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
      targetDate: _targetDate,
    );
    controller.add(quest);
    ref.read(questGuideControllerProvider.notifier).generateForQuest(quest);
    context.go('${AppRoutes.quest}/${quest.id}');
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

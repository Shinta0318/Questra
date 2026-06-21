import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/questra_card.dart';
import '../media/media_model.dart';
import 'trail_model.dart';
import 'trail_timeline_service.dart';

class TrailTimelineWidget extends StatelessWidget {
  const TrailTimelineWidget({
    required this.trails,
    required this.attachments,
    super.key,
    this.service = const TrailTimelineService(),
  });

  final List<Trail> trails;
  final Map<String, MediaAttachment> attachments;
  final TrailTimelineService service;

  @override
  Widget build(BuildContext context) {
    if (trails.isEmpty) {
      return const ArcEmptyState(
        title: 'Timelineはまだ静かです',
        emotion: ArcEmotion.normal,
        message: 'Trailを残すと、日付ごとの航路としてここに並びます。',
        actionLabel: 'Trailを残す',
        icon: Icons.timeline_outlined,
        onAction: _noop,
      );
    }

    final days = service.groupByDay(trails);
    return QuestraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trail Timeline', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('QuestとMissionの足あとを、日付ごとに戻れる航路として見返せます。'),
          const SizedBox(height: 16),
          ...days.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TimelineDaySection(day: day, attachments: attachments),
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}

class _TimelineDaySection extends StatelessWidget {
  const _TimelineDaySection({required this.day, required this.attachments});

  final TrailTimelineDay day;
  final Map<String, MediaAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day.dateLabel,
          style: const TextStyle(
            color: QuestraColors.cosmicBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...day.trails.map(
          (trail) => _TimelineTrailTile(
            trail: trail,
            attachment: attachments[trail.id],
          ),
        ),
      ],
    );
  }
}

class _TimelineTrailTile extends StatelessWidget {
  const _TimelineTrailTile({required this.trail, required this.attachment});

  final Trail trail;
  final MediaAttachment? attachment;

  @override
  Widget build(BuildContext context) {
    final hasReflection = trail.trailType == TrailType.arcReflection;
    final hasMedia = attachment != null;
    final timeLabel = DateFormat.Hm('ja').format(trail.createdAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasReflection
                      ? QuestraColors.gold
                      : QuestraColors.cosmicBlue,
                ),
              ),
              Expanded(child: Container(width: 2, color: QuestraColors.cloud)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: QuestraColors.cloud.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: QuestraColors.cosmicBlue.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            color: QuestraColors.slate,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TimelinePill(label: trail.trailType.label),
                        if (hasReflection) ...[
                          const SizedBox(width: 6),
                          const _TimelinePill(label: 'Arc'),
                        ],
                        if (hasMedia) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: QuestraColors.cosmicBlue,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trail.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(trail.summary),
                    if (hasMedia) ...[
                      const SizedBox(height: 8),
                      _TimelineMediaChip(attachment: attachment!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePill extends StatelessWidget {
  const _TimelinePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: QuestraColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: QuestraColors.deepNavy,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimelineMediaChip extends StatelessWidget {
  const _TimelineMediaChip({required this.attachment});

  final MediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final fileName = attachment.path.split('/').last;
    return Row(
      children: [
        const Icon(
          Icons.photo_size_select_actual_outlined,
          size: 16,
          color: QuestraColors.cosmicBlue,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: QuestraColors.slate,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

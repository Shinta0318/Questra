import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/questra_colors.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/questra_card.dart';
import '../media/media_model.dart';
import 'trail_highlight_service.dart';
import 'trail_model.dart';
import 'trail_timeline_service.dart';

class TrailTimelineWidget extends StatelessWidget {
  const TrailTimelineWidget({
    required this.trails,
    required this.attachments,
    super.key,
    this.highlights = const {},
    this.service = const TrailTimelineService(),
  });

  final List<Trail> trails;
  final Map<String, MediaAttachment> attachments;
  final Map<String, TrailHighlight> highlights;
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
              child: _TimelineDaySection(
                day: day,
                attachments: attachments,
                highlights: highlights,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}

class _TimelineDaySection extends StatelessWidget {
  const _TimelineDaySection({
    required this.day,
    required this.attachments,
    required this.highlights,
  });

  final TrailTimelineDay day;
  final Map<String, MediaAttachment> attachments;
  final Map<String, TrailHighlight> highlights;

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
            highlight: highlights[trail.id],
          ),
        ),
      ],
    );
  }
}

class _TimelineTrailTile extends StatelessWidget {
  const _TimelineTrailTile({
    required this.trail,
    required this.attachment,
    required this.highlight,
  });

  final Trail trail;
  final MediaAttachment? attachment;
  final TrailHighlight? highlight;

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
                        if (highlight?.isStarMemoryCandidate == true) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: QuestraColors.gold,
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
                    if (highlight != null) ...[
                      const SizedBox(height: 8),
                      _TimelineHighlightHint(highlight: highlight!),
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

class _TimelineHighlightHint extends StatelessWidget {
  const _TimelineHighlightHint({required this.highlight});

  final TrailHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: QuestraColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: QuestraColors.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            highlight.isStarMemoryCandidate
                ? Icons.auto_awesome
                : Icons.star_border,
            size: 18,
            color: QuestraColors.gold,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              highlight.isStarMemoryCandidate
                  ? 'Star Memory候補: ${highlight.reason}'
                  : highlight.reason,
              style: const TextStyle(
                color: QuestraColors.deepNavy,
                fontWeight: FontWeight.w800,
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

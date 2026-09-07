import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/feature_flags/locale_feature_flags.dart';
import '../../core/theme/questra_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/arc/arc_empty_state.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/questra_card.dart';
import '../media/media_model.dart';
import 'trail_highlight_service.dart';
import 'trail_model.dart';
import 'trail_timeline_service.dart';

typedef TrailTimelineItemBuilder =
    Widget Function(BuildContext context, Trail trail);

class TrailTimelineWidget extends StatelessWidget {
  const TrailTimelineWidget({
    required this.trails,
    required this.attachments,
    super.key,
    this.highlights = const {},
    this.hierarchyByTrailId = const {},
    this.service = const TrailTimelineService(),
    this.onCreateTrail,
    this.itemBuilder,
  });

  final List<Trail> trails;
  final Map<String, MediaAttachment> attachments;
  final Map<String, TrailHighlight> highlights;
  final Map<String, TrailParentContext> hierarchyByTrailId;
  final TrailTimelineService service;
  final VoidCallback? onCreateTrail;
  final TrailTimelineItemBuilder? itemBuilder;

  @override
  Widget build(BuildContext context) {
    final localizedCopyEnabled =
        const LocaleFeatureFlags().localizedJourneyCopyV2Enabled;
    final copy = localizedCopyEnabled ? AppLocalizations.of(context) : null;
    if (trails.isEmpty) {
      return ArcEmptyState(
        title: copy?.trailEmptyTitle ?? 'まだTrailはありません',
        emotion: ArcEmotion.normal,
        message: copy?.trailEmptyMessage ?? '今日進んだことを、短い言葉から残してみよう。',
        actionLabel: onCreateTrail == null
            ? null
            : copy?.createFirstTrail ?? '最初のTrailを残す',
        actionKey: const ValueKey('trail-primary-create'),
        onAction: onCreateTrail,
        icon: Icons.add,
      );
    }

    final days = service.groupByDay(trails);
    final reflectionCount = trails
        .where((trail) => trail.trailType == TrailType.arcReflection)
        .length;
    final starCandidateCount = highlights.values
        .where((highlight) => highlight.isStarMemoryCandidate)
        .length;
    final mediaCount = attachments.length;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                copy?.trailHistoryTitle ?? 'これまでのTrail',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (onCreateTrail != null)
              OutlinedButton.icon(
                key: const ValueKey('trail-primary-create'),
                onPressed: onCreateTrail,
                icon: const Icon(Icons.add),
                label: Text(copy?.createTrail ?? 'Trailを残す'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(copy?.trailHistoryDescription ?? '進んだ日ごとに、旅の記録を振り返れます。'),
        const SizedBox(height: 14),
        _TimelineSummary(
          trailCount: trails.length,
          reflectionCount: reflectionCount,
          starCandidateCount: starCandidateCount,
          mediaCount: mediaCount,
        ),
        const SizedBox(height: 16),
        ...days.map(
          (day) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _TimelineDaySection(
              day: day,
              attachments: attachments,
              highlights: highlights,
              hierarchyByTrailId: hierarchyByTrailId,
              itemBuilder: itemBuilder,
            ),
          ),
        ),
      ],
    );

    if (itemBuilder != null) return content;
    return QuestraCard(padding: const EdgeInsets.all(16), child: content);
  }
}

class _TimelineDaySection extends StatelessWidget {
  const _TimelineDaySection({
    required this.day,
    required this.attachments,
    required this.highlights,
    required this.hierarchyByTrailId,
    required this.itemBuilder,
  });

  final TrailTimelineDay day;
  final Map<String, MediaAttachment> attachments;
  final Map<String, TrailHighlight> highlights;
  final Map<String, TrailParentContext> hierarchyByTrailId;
  final TrailTimelineItemBuilder? itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                day.dateLabel,
                style: const TextStyle(
                  color: QuestraColors.cosmicBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _TimelinePill(
              label:
                  AppLocalizations.of(context)?.trailCount(day.trails.length) ??
                  'Trail ${day.trails.length}件',
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...day.trails.map((trail) {
          final builder = itemBuilder;
          if (builder != null) return builder(context, trail);
          return _TimelineTrailTile(
            trail: trail,
            attachment: attachments[trail.id],
            highlight: highlights[trail.id],
            parent: hierarchyByTrailId[trail.id],
          );
        }),
      ],
    );
  }
}

class _TimelineSummary extends StatelessWidget {
  const _TimelineSummary({
    required this.trailCount,
    required this.reflectionCount,
    required this.starCandidateCount,
    required this.mediaCount,
  });

  final int trailCount;
  final int reflectionCount;
  final int starCandidateCount;
  final int mediaCount;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TimelineSummaryChip(
          icon: Icons.timeline_outlined,
          label: 'Trail',
          value: trailCount.toString(),
        ),
        if (reflectionCount > 0)
          _TimelineSummaryChip(
            icon: Icons.auto_awesome_outlined,
            label: copy?.reflection ?? '振り返り',
            value: reflectionCount.toString(),
          ),
        if (starCandidateCount > 0)
          _TimelineSummaryChip(
            icon: Icons.star_border,
            label: copy?.starCandidate ?? '大切な記録の候補',
            value: starCandidateCount.toString(),
          ),
        if (mediaCount > 0)
          _TimelineSummaryChip(
            icon: Icons.image_outlined,
            label: copy?.image ?? '画像',
            value: mediaCount.toString(),
          ),
      ],
    );
  }
}

class _TimelineSummaryChip extends StatelessWidget {
  const _TimelineSummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: QuestraColors.cosmicBlue.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: QuestraColors.cosmicBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: QuestraColors.deepNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: QuestraColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTrailTile extends StatelessWidget {
  const _TimelineTrailTile({
    required this.trail,
    required this.attachment,
    required this.highlight,
    required this.parent,
  });

  final Trail trail;
  final MediaAttachment? attachment;
  final TrailHighlight? highlight;
  final TrailParentContext? parent;

  @override
  Widget build(BuildContext context) {
    final hasReflection = trail.trailType == TrailType.arcReflection;
    final hasMedia = attachment != null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final timeLabel = DateFormat.Hm(locale).format(trail.createdAt);
    final copy = AppLocalizations.of(context);

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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            color: QuestraColors.slate,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _TimelinePill(
                          label: _localizedTrailType(copy, trail.trailType),
                        ),
                        if (hasReflection) const _TimelinePill(label: 'Arc'),
                        if (hasMedia)
                          const Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: QuestraColors.cosmicBlue,
                          ),
                        if (highlight?.isStarMemoryCandidate == true)
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: QuestraColors.gold,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trail.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(trail.summary),
                    if (parent case final hierarchy?) ...[
                      const SizedBox(height: 8),
                      _TimelineHierarchy(parent: hierarchy),
                    ],
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

class _TimelineHierarchy extends StatelessWidget {
  const _TimelineHierarchy({required this.parent});

  final TrailParentContext parent;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _TimelinePill(
          label:
              copy?.questContext(parent.questTitle) ??
              'Quest: ${parent.questTitle}',
        ),
        if (parent.missionTitle case final title?)
          _TimelinePill(
            label: copy?.missionContext(title) ?? 'Mission: $title',
          ),
        if (parent.taskTitle case final title?)
          _TimelinePill(label: copy?.taskContext(title) ?? 'Task: $title'),
      ],
    );
  }
}

class _TimelineHighlightHint extends StatelessWidget {
  const _TimelineHighlightHint({required this.highlight});

  final TrailHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context);
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
                  ? copy?.starMemoryCandidate(highlight.reason) ??
                        '大切な記録の候補：${highlight.reason}'
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

String _localizedTrailType(AppLocalizations? copy, TrailType type) {
  if (copy == null) return type.label;
  return switch (type) {
    TrailType.questRecord => copy.trailTypeQuest,
    TrailType.missionRecord => copy.trailTypeMission,
    TrailType.arcReflection => copy.trailTypeArcReflection,
    TrailType.manualNote => copy.trailTypeManual,
  };
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

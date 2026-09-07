import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/questra_card.dart';
import 'trail_share_providers.dart';
import 'trail_share_repository.dart';

class TrailShareScreen extends ConsumerStatefulWidget {
  const TrailShareScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<TrailShareScreen> createState() => _TrailShareScreenState();
}

class _TrailShareScreenState extends ConsumerState<TrailShareScreen> {
  TrailShareSnapshot? _snapshot;
  bool _loading = true;
  bool _reporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(trailShareRepositoryProvider);
    if (repository == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(widget.token)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snapshot = await repository.resolve(widget.token);
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (_) {
      if (mounted) {
        setState(
          () => _snapshot = const TrailShareSnapshot(
            availability: TrailShareAvailability.notAvailable,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        leading: IconButton(
          tooltip: Navigator.of(context).canPop() ? '戻る' : 'ホームへ戻る',
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go(AppRoutes.home),
          icon: Icon(
            Navigator.of(context).canPop()
                ? Icons.arrow_back
                : Icons.home_outlined,
          ),
        ),
        title: const Text('共有されたTrail'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final snapshot = _snapshot;
    if (snapshot == null ||
        snapshot.availability == TrailShareAvailability.notAvailable) {
      return _UnavailableCard(
        title: 'このTrailを確認できません',
        message: 'リンクが無効、期限切れ、撤回済み、または安全確認中の可能性があります。',
        onRecover: () => context.go(AppRoutes.home),
      );
    }
    if (snapshot.availability == TrailShareAvailability.rateLimited) {
      return _UnavailableCard(
        title: '少し時間をおいてください',
        message: '短時間に確認が続きました。10分ほど待ってから、もう一度開いてください。',
        onRecover: () => context.go(AppRoutes.home),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.route_outlined, color: AppColors.gold),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Navigatorが選んだ旅の記録',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              if (snapshot.title case final title?) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ],
              if (snapshot.summary case final summary?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(summary, style: Theme.of(context).textTheme.titleMedium),
              ],
              if (snapshot.content case final content?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(content),
              ],
              if (snapshot.expiresAt case final expiresAt?) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '共有期限 ${expiresAt.year}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'この画面から送信者のプロフィール、元のQuest、画像へ移動することはできません。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.parchment),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: _reporting ? null : _chooseReportReason,
          icon: const Icon(Icons.flag_outlined),
          label: Text(_reporting ? '送信中' : 'この共有を報告'),
        ),
      ],
    );
  }

  Future<void> _chooseReportReason() async {
    final reason = await showDialog<TrailShareReportReason>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('報告する理由'),
        children: TrailShareReportReason.values
            .map(
              (reason) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, reason),
                child: Text(reason.label),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _reporting = true);
    try {
      await ref
          .read(trailShareRepositoryProvider)
          ?.report(token: widget.token, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告を受け付けました。ご協力ありがとうございます。')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('報告できませんでした。時間をおいてお試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({
    required this.title,
    required this.message,
    required this.onRecover,
  });

  final String title;
  final String message;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return QuestraCard(
      child: Column(
        children: [
          const Icon(Icons.link_off_rounded, size: 42, color: AppColors.gold),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onRecover,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Questraを開く'),
            ),
          ),
        ],
      ),
    );
  }
}

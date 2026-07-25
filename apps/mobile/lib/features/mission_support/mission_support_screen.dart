import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/layout/questra_screen_surface.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import 'mission_support_model.dart';
import 'mission_support_providers.dart';

class MissionSupportScreen extends ConsumerStatefulWidget {
  const MissionSupportScreen({super.key, required this.missionId});

  final String missionId;

  @override
  ConsumerState<MissionSupportScreen> createState() =>
      _MissionSupportScreenState();
}

class _MissionSupportScreenState extends ConsumerState<MissionSupportScreen> {
  MissionResearchResult? _result;
  String? _error;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final mission = ref
        .watch(missionControllerProvider)
        .where((item) => item.id == widget.missionId)
        .firstOrNull;
    return QuestraScreenSurface(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: context.pop,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '戻る'),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Missionの実行サポート',
                      style: Theme.of(context).textTheme.headlineSmall)),
            ],
          ),
          if (mission == null)
            const _SupportSection(
                title: 'Missionが見つかりません',
                child: Text('QuestからMissionを選び直してください。'))
          else ...[
            _MissionHeader(mission: mission),
            const SizedBox(height: 16),
            _SupportSection(
              title: 'Arcが調べた情報',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_result == null && !_loading)
                    const Text('必要なときだけ最新情報を検索します。Questやチャットの無関係な内容は送信しません。'),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  if (_result case final result?) ...[
                    Text(result.summary),
                    const SizedBox(height: 12),
                    ...result.references.map((source) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.open_in_new),
                          title: Text(source.title),
                          subtitle: Text(
                              '${source.publisher} / ${source.verified ? '検索結果で確認済み' : '要確認'}'),
                          onTap: () => launchUrl(source.url,
                              mode: LaunchMode.externalApplication),
                        )),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _research(mission),
                    icon: const Icon(Icons.travel_explore),
                    label: Text(_result == null ? 'Arcに調べてもらう' : '情報を更新する'),
                  ),
                ],
              ),
            ),
            if (_result case final result?) ...[
              const SizedBox(height: 16),
              _SupportSection(
                  title: '実行のポイント', child: _BulletList(result.checkpoints)),
              const SizedBox(height: 16),
              _SupportSection(
                  title: '安全上の確認', child: _BulletList(result.cautions)),
            ],
            const SizedBox(height: 16),
            const _SupportSection(
              title: '企業からの支援',
              child: Text('現在利用できる、審査済みの支援はありません。Arcが調べた情報とは分けて表示されます。'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _research(Mission mission) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(missionResearchServiceProvider).research(
            mission,
            forceRefresh: _result != null,
          );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '最新情報を取得できませんでした。接続を確認して、もう一度試してください。');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({required this.mission});
  final Mission mission;
  @override
  Widget build(BuildContext context) => _SupportSection(
        title: mission.title,
        child: Text('Quest: ${mission.questTitle}'),
      );
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

class _BulletList extends StatelessWidget {
  const _BulletList(this.items);
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('・$item')))
            .toList(),
      );
}

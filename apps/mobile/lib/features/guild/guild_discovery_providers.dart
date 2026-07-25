import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'guild_discovery_model.dart';
import 'guild_discovery_ranking_service.dart';
import 'guild_discovery_repository.dart';

final guildDiscoveryRepositoryProvider = Provider<GuildDiscoveryRepository?>((
  ref,
) {
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseGuildDiscoveryRepository(Supabase.instance.client);
});

final guildDiscoveryRankingServiceProvider =
    Provider<GuildDiscoveryRankingService>((ref) {
      return const GuildDiscoveryRankingService();
    });

final guildDiscoveryFeedProvider = FutureProvider<List<GuildDiscoveryQuest>>((
  ref,
) async {
  final repository = ref.watch(guildDiscoveryRepositoryProvider);
  if (repository == null) return const <GuildDiscoveryQuest>[];
  return repository.findApprovedPublic(limit: 40);
});

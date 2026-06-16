import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'trail_event_repository.dart';
import 'trail_repository.dart';

final trailRepositoryProvider = Provider<TrailRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseTrailRepository(Supabase.instance.client);
  }
  return InMemoryTrailRepository();
});

final trailEventRepositoryProvider = Provider<TrailEventRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseTrailEventRepository(Supabase.instance.client);
  }
  return InMemoryTrailEventRepository();
});

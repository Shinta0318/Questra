import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'mission_repository.dart';

final missionRepositoryProvider = Provider<MissionRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseMissionRepository(Supabase.instance.client);
  }
  return InMemoryMissionRepository();
});

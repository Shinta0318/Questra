import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'trail_share_repository.dart';

final trailShareRepositoryProvider = Provider<TrailShareRepository?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseTrailShareRepository(Supabase.instance.client);
});

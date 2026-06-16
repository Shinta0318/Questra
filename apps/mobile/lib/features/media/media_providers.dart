import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'media_repository.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseMediaRepository(Supabase.instance.client);
  }
  return InMemoryMediaRepository();
});

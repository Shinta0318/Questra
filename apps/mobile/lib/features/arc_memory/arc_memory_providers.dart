import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'arc_memory_repository.dart';
import 'memory_extraction_service.dart';

final arcMemoryRepositoryProvider = Provider<ArcMemoryRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseArcMemoryRepository(Supabase.instance.client);
  }
  return InMemoryArcMemoryRepository();
});

final memoryExtractionServiceProvider = Provider<MemoryExtractionService>((
  ref,
) {
  return MemoryExtractionService(
    repository: ref.watch(arcMemoryRepositoryProvider),
  );
});

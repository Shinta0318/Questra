import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'ai_tag_service.dart';
import 'tag_repository.dart';
import 'tagging_service.dart';

final aiTagServiceProvider = Provider<AiTagService>((ref) {
  return const LocalAiTagService();
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseTagRepository(Supabase.instance.client);
  }
  return InMemoryTagRepository();
});

final taggingServiceProvider = Provider<TaggingService>((ref) {
  return TaggingService(
    aiTagService: ref.watch(aiTagServiceProvider),
    repository: ref.watch(tagRepositoryProvider),
  );
});

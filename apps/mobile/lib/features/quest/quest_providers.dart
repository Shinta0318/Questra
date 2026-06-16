import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'quest_guide_repository.dart';
import 'quest_repository.dart';

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseQuestRepository(Supabase.instance.client);
  }
  return InMemoryQuestRepository();
});

final questGuideRepositoryProvider = Provider<QuestGuideRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseQuestGuideRepository(Supabase.instance.client);
  }
  return InMemoryQuestGuideRepository();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseTaskRepository(Supabase.instance.client);
  }
  return InMemoryTaskRepository();
});

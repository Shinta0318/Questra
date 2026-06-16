import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'arc_advice_service.dart';

final arcAdviceServiceProvider = Provider<ArcAdviceService>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseArcAdviceService(client: Supabase.instance.client);
  }
  return const LocalArcAdviceService();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'arc_celebration_service.dart';
import 'arc_chat_service.dart';
import 'arc_expression_engine.dart';
import 'arc_guidance_service.dart';

final arcGuidanceServiceProvider = Provider<ArcGuidanceService>((ref) {
  return const ArcGuidanceService();
});

final arcExpressionEngineProvider = Provider<ArcExpressionEngine>((ref) {
  return const ArcExpressionEngine();
});

final arcCelebrationServiceProvider = Provider<ArcCelebrationService>((ref) {
  return ArcCelebrationService(
    expressionEngine: ref.watch(arcExpressionEngineProvider),
  );
});

final arcChatServiceProvider = Provider<ArcChatService>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseArcChatService(client: Supabase.instance.client);
  }
  return const LocalArcChatService();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import 'mission_research_service.dart';

final missionResearchServiceProvider = Provider<MissionResearchService>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseMissionResearchService(Supabase.instance.client);
  }
  return const LocalMissionResearchService();
});

abstract final class MissionSupportFlags {
  static const enterpriseSupportPreview = false;
}

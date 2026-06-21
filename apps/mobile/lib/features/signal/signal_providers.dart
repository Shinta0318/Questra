import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mission_signal_service.dart';

final missionSignalServiceProvider = Provider<MissionSignalService>((ref) {
  return const MissionSignalService();
});

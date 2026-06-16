import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'arc_guidance_service.dart';

final arcGuidanceServiceProvider = Provider<ArcGuidanceService>((ref) {
  return const ArcGuidanceService();
});

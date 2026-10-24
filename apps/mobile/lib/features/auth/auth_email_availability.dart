import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';

final authEmailAvailableProvider = Provider<bool>(
  (ref) => SupabaseConfig.isConfigured,
);

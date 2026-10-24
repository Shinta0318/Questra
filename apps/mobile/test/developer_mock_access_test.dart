import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/config/supabase_config.dart';

void main() {
  test('automatic preview requires explicit request and an offline mock', () {
    expect(
      SupabaseConfig.resolveAutoEnterLocalMock(
        requested: true,
        isReleaseMode: false,
        isLocalMockPreview: true,
      ),
      isTrue,
    );
    for (final inputs in [
      (false, false, true),
      (true, true, true),
      (true, false, false),
    ]) {
      expect(
        SupabaseConfig.resolveAutoEnterLocalMock(
          requested: inputs.$1,
          isReleaseMode: inputs.$2,
          isLocalMockPreview: inputs.$3,
        ),
        isFalse,
      );
    }
  });
}

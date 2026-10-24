import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/safety/ai_legal_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

void main() {
  test('missing consent is distinct from a temporary check failure', () {
    expect(
      aiLegalFailureMessage(
        const FunctionException(
          status: 403,
          details: {'error': 'consent_required'},
        ),
      ),
      contains('AIへ送っていません'),
    );
    expect(
      aiLegalFailureReason(
        const FunctionException(
          status: 403,
          details: {'error': 'consent_required'},
        ),
      ),
      'consent_required',
    );
    expect(
      aiLegalFailureMessage(
        const FunctionException(
          status: 503,
          details: {'error': 'consent_check_unavailable'},
        ),
      ),
      contains('再試行'),
    );
    expect(
      aiLegalFailureMessage(
        const FunctionException(
          status: 403,
          details: {'error': 'quest_not_found'},
        ),
      ),
      isNull,
    );
    expect(
      aiLegalFailureReason(
        const FunctionException(
          status: 503,
          details: {'error': 'consent_check_unavailable'},
        ),
      ),
      'consent_check_unavailable',
    );
  });
}

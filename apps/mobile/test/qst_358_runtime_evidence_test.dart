import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/observability/runtime_evidence.dart';

void main() {
  RuntimeEvidence evidence({String errorCode = 'network_timeout'}) {
    return RuntimeEvidence(
      eventId: 'event-1',
      occurredAt: DateTime.utc(2026, 8, 25),
      buildVersion: 'candidate:abc123',
      environment: 'internal_beta',
      platform: 'android',
      surface: 'arc_chat',
      operation: 'arc_chat.invoke',
      type: RuntimeEvidenceType.aiFallback,
      severity: RuntimeEvidenceSeverity.s2,
      errorCode: errorCode,
      correlationId: 'trace-1',
      handled: true,
      fallbackUsed: true,
    );
  }

  test('serializes only the minimum evidence contract', () {
    final map = evidence().toSafeMap();
    expect(map['event_type'], 'aiFallback');
    expect(map['severity'], 'S2');
    expect(map['fallback_used'], isTrue);
    expect(map.keys, isNot(contains('message')));
    expect(map.keys, isNot(contains('quest_text')));
    expect(map.keys, isNot(contains('user_id')));
  });

  test('rejects raw messages and contact details in normalized codes', () {
    const policy = RuntimeEvidencePolicy();
    expect(policy.accepts(evidence()), isTrue);
    expect(policy.accepts(evidence(errorCode: 'user@example.com')), isFalse);
    expect(
      policy.accepts(evidence(errorCode: 'network timeout details')),
      isFalse,
    );
  });

  test('default sink never sends evidence outside the device', () async {
    const sink = NoopRuntimeEvidenceSink();
    await expectLater(sink.record(evidence()), completes);
  });
}

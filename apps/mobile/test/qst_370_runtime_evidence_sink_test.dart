import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/observability/runtime_evidence.dart';
import 'package:questra/core/observability/runtime_evidence_sink.dart';
import 'dart:io';

void main() {
  RuntimeEvidence evidence({String errorCode = 'network_timeout'}) =>
      RuntimeEvidence(
        eventId: 'event-1',
        occurredAt: DateTime.now().toUtc(),
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

  test('hosted sink sends only the safe evidence contract', () async {
    final transport = _RecordingTransport();
    final sink = HostedRuntimeEvidenceSink(transport: transport);
    await sink.record(evidence());
    expect(transport.events, hasLength(1));
    expect(transport.events.single.keys, isNot(contains('user_id')));
    expect(transport.events.single.keys, isNot(contains('message')));
    expect(transport.events.single.keys, isNot(contains('quest_text')));
  });

  test('unsafe tokens are dropped before transport', () async {
    final transport = _RecordingTransport();
    final sink = HostedRuntimeEvidenceSink(transport: transport);
    await sink.record(evidence(errorCode: 'user@example.com'));
    expect(transport.events, isEmpty);
  });

  test('transport failure never escapes into the product journey', () async {
    const sink = HostedRuntimeEvidenceSink(transport: _FailingTransport());
    await expectLater(sink.record(evidence()), completes);
  });

  test('hosted collection remains disabled unless explicitly configured', () {
    expect(RuntimeEvidenceConfig.hostedSinkEnabled, isFalse);
  });

  test('server sink rate limits event and high-severity floods per owner', () {
    final migration = File(
      '../../supabase/migrations/202608250008_privacy_safe_runtime_observability.sql',
    ).readAsStringSync();
    expect(migration, contains('runtime_evidence_rate_buckets'));
    expect(migration, contains('v_event_count > 120'));
    expect(migration, contains('v_high_severity_count > 10'));
  });
}

class _RecordingTransport implements RuntimeEvidenceTransport {
  final events = <Map<String, Object>>[];

  @override
  Future<void> send(Map<String, Object> event) async => events.add(event);
}

class _FailingTransport implements RuntimeEvidenceTransport {
  const _FailingTransport();

  @override
  Future<void> send(Map<String, Object> event) async {
    throw StateError('transport unavailable');
  }
}

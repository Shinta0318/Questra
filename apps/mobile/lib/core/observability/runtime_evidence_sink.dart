import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'runtime_evidence.dart';

class RuntimeEvidenceConfig {
  const RuntimeEvidenceConfig._();

  static const hostedSinkEnabled = bool.fromEnvironment(
    'ENABLE_RUNTIME_EVIDENCE_SINK',
    defaultValue: false,
  );
}

abstract interface class RuntimeEvidenceTransport {
  Future<void> send(Map<String, Object> event);
}

class SupabaseRuntimeEvidenceTransport implements RuntimeEvidenceTransport {
  const SupabaseRuntimeEvidenceTransport(this.client);

  final SupabaseClient client;

  @override
  Future<void> send(Map<String, Object> event) async {
    await client.rpc<void>(
      'record_runtime_evidence',
      params: {'p_event': event},
    );
  }
}

class HostedRuntimeEvidenceSink implements RuntimeEvidenceSink {
  const HostedRuntimeEvidenceSink({
    required this.transport,
    this.policy = const RuntimeEvidencePolicy(),
  });

  final RuntimeEvidenceTransport transport;
  final RuntimeEvidencePolicy policy;

  @override
  Future<void> record(RuntimeEvidence evidence) async {
    if (!policy.accepts(evidence)) return;
    try {
      await transport.send(evidence.toSafeMap());
    } on Object {
      // Evidence transport must never break the user's primary journey.
    }
  }
}

final runtimeEvidenceSinkProvider = Provider<RuntimeEvidenceSink>((ref) {
  if (!RuntimeEvidenceConfig.hostedSinkEnabled ||
      !SupabaseConfig.isConfigured) {
    return const NoopRuntimeEvidenceSink();
  }
  return HostedRuntimeEvidenceSink(
    transport: SupabaseRuntimeEvidenceTransport(Supabase.instance.client),
  );
});

import 'dart:io';

import 'external_beta_go_no_go.dart';

void main() {
  final decision = evaluateExternalBetaReadiness();
  final output = renderExternalBetaDecision(
    decision,
    evaluatedAt: DateTime.now(),
  );
  File(externalBetaDecisionPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(output);
  stdout.writeln(
    'External Beta decision: ${decision.decision} '
    '(${decision.gates.where((gate) => !gate.passed).length} blocked gates).',
  );
}

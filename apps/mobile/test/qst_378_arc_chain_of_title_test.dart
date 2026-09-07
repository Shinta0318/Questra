import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = Directory.current.parent.parent;

  test('Arc chain-of-title intake is hash-bound and approval-gated', () {
    final intake = File(
      '${repo.path}/tools/qst/intake_arc_asset_chain_of_title.dart',
    ).readAsStringSync();
    expect(intake, contains("record['assetSha256'] != actualHash"));
    expect(intake, contains("record['productDecision'] != 'approved'"));
    expect(intake, contains("record['legalDecision'] != 'approved'"));
    expect(intake, contains("commercialDistributionAllowed"));
    expect(intake, contains('_rejectSensitiveFields'));
  });

  test('release verifier requires records only for bundled runtime assets', () {
    final verifier = File(
      '${repo.path}/tools/qst/verify_arc_asset_provenance.dart',
    ).readAsStringSync();
    expect(verifier, contains("usage == 'runtime'"));
    expect(verifier, contains('Runtime asset lacks a reviewed chain-of-title record'));
    expect(verifier, contains('record_asset_hash_mismatch_allowed: false'));

    final manifest = File(
      '${repo.path}/docs/qst/ARC_ASSET_PROVENANCE.yaml',
    ).readAsStringSync();
    expect(manifest, contains('chain_of_title_complete: false'));
    expect(manifest, contains('product_owner_approval: pending'));
    expect(manifest, contains('legal_reviewer_approval: pending'));
  });
}

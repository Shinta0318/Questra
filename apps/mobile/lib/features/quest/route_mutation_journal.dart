import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'route_snapshot_service.dart';

final routeMutationJournalRepositoryProvider =
    Provider<RouteMutationJournalRepository>(
      (ref) => SecureRouteMutationJournalRepository(),
    );

enum RouteJournalStage { applying, applied, recovering, recoveryNeeded }

enum RouteJournalDisposition { notApplied, applied, recoveryNeeded, unknown }

class RouteJournalInspection {
  const RouteJournalInspection({
    required this.proposalId,
    required this.stage,
    required this.disposition,
    required this.createdAt,
    required this.matchesBefore,
    required this.matchesAfter,
  });

  final String proposalId;
  final RouteJournalStage stage;
  final RouteJournalDisposition disposition;
  final DateTime createdAt;
  final bool matchesBefore;
  final bool matchesAfter;

  bool get canAcknowledge =>
      (stage == RouteJournalStage.applying &&
          disposition == RouteJournalDisposition.notApplied) ||
      (stage == RouteJournalStage.applied &&
          disposition == RouteJournalDisposition.applied) ||
      (stage == RouteJournalStage.recoveryNeeded && matchesBefore) ||
      (stage == RouteJournalStage.recovering && matchesAfter);
}

class RouteMutationJournal {
  const RouteMutationJournal({
    required this.ownerId,
    required this.questId,
    required this.proposalId,
    required this.stage,
    required this.beforeSnapshot,
    required this.createdAt,
    this.afterSnapshot,
    this.attempts = 0,
  });

  final String ownerId;
  final String questId;
  final String proposalId;
  final RouteJournalStage stage;
  final Map<String, Object?> beforeSnapshot;
  final Map<String, Object?>? afterSnapshot;
  final DateTime createdAt;
  final int attempts;

  RouteMutationJournal copyWith({
    RouteJournalStage? stage,
    Map<String, Object?>? afterSnapshot,
    int? attempts,
  }) => RouteMutationJournal(
    ownerId: ownerId,
    questId: questId,
    proposalId: proposalId,
    stage: stage ?? this.stage,
    beforeSnapshot: beforeSnapshot,
    afterSnapshot: afterSnapshot ?? this.afterSnapshot,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
  );

  RouteJournalDisposition disposition(Map<String, Object?> current) {
    if (stage == RouteJournalStage.recoveryNeeded) {
      return RouteJournalDisposition.recoveryNeeded;
    }
    const snapshots = RouteSnapshotService();
    if (!snapshots.compare(beforeSnapshot, current).isStale) {
      return RouteJournalDisposition.notApplied;
    }
    if (afterSnapshot != null &&
        !snapshots.compare(afterSnapshot!, current).isStale) {
      return RouteJournalDisposition.applied;
    }
    return RouteJournalDisposition.unknown;
  }
}

abstract interface class RouteMutationJournalRepository {
  Future<RouteMutationJournal?> load(String ownerId, String questId);
  Future<void> save(RouteMutationJournal journal);
  Future<void> clear(String ownerId, String questId);
}

class SecureRouteMutationJournalRepository
    implements RouteMutationJournalRepository {
  SecureRouteMutationJournalRepository({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 7),
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const _keyPrefix = 'questra_route_journal_v1_';
  static const _maxEncodedBytes = 256 * 1024;
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final Duration maxAge;

  @override
  Future<RouteMutationJournal?> load(String ownerId, String questId) async {
    if (!_validId(ownerId) || !_validId(questId)) return null;
    final key = _key(ownerId, questId);
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null) return null;
      if (encoded.length > _maxEncodedBytes) {
        throw const RouteJournalIntegrityException();
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const RouteJournalIntegrityException();
      final row = Map<String, dynamic>.from(decoded);
      final createdAt = DateTime.tryParse(row['createdAt'] as String? ?? '');
      final before = row['beforeSnapshot'];
      final after = row['afterSnapshot'];
      final stage = RouteJournalStage.values
          .where((value) => value.name == row['stage'])
          .firstOrNull;
      if (row['version'] != 1 ||
          row['ownerId'] != ownerId ||
          row['questId'] != questId ||
          !_validId(row['proposalId'] as String? ?? '') ||
          createdAt == null ||
          _clock().toUtc().difference(createdAt.toUtc()) > maxAge ||
          stage == null ||
          before is! Map ||
          before['snapshotVersion'] != RouteSnapshotService.snapshotVersion ||
          (after != null &&
              (after is! Map ||
                  after['snapshotVersion'] !=
                      RouteSnapshotService.snapshotVersion))) {
        throw const RouteJournalIntegrityException();
      }
      return RouteMutationJournal(
        ownerId: ownerId,
        questId: questId,
        proposalId: row['proposalId'] as String,
        stage: stage,
        beforeSnapshot: Map<String, Object?>.from(before),
        afterSnapshot: after is Map ? Map<String, Object?>.from(after) : null,
        createdAt: createdAt,
        attempts: (row['attempts'] as int? ?? 0).clamp(0, 20),
      );
    } catch (_) {
      throw const RouteJournalIntegrityException();
    }
  }

  @override
  Future<void> save(RouteMutationJournal journal) async {
    if (!_validId(journal.ownerId) ||
        !_validId(journal.questId) ||
        !_validId(journal.proposalId) ||
        journal.attempts < 0 ||
        journal.attempts > 20 ||
        journal.beforeSnapshot['snapshotVersion'] !=
            RouteSnapshotService.snapshotVersion ||
        (journal.afterSnapshot != null &&
            journal.afterSnapshot!['snapshotVersion'] !=
                RouteSnapshotService.snapshotVersion)) {
      throw ArgumentError('Route journal contract is invalid.');
    }
    final encoded = jsonEncode({
      'version': 1,
      'ownerId': journal.ownerId,
      'questId': journal.questId,
      'proposalId': journal.proposalId,
      'stage': journal.stage.name,
      'beforeSnapshot': journal.beforeSnapshot,
      'afterSnapshot': journal.afterSnapshot,
      'attempts': journal.attempts,
      'createdAt': journal.createdAt.toUtc().toIso8601String(),
    });
    if (encoded.length > _maxEncodedBytes) {
      throw StateError('Route journal is too large.');
    }
    await _storage.write(
      key: _key(journal.ownerId, journal.questId),
      value: encoded,
    );
  }

  @override
  Future<void> clear(String ownerId, String questId) =>
      _storage.delete(key: _key(ownerId, questId));

  String _key(String ownerId, String questId) =>
      '$_keyPrefix${base64Url.encode(utf8.encode(ownerId))}_${base64Url.encode(utf8.encode(questId))}';

  bool _validId(String value) => value.isNotEmpty && value.length <= 128;
}

class RouteJournalIntegrityException implements Exception {
  const RouteJournalIntegrityException();

  @override
  String toString() => '航路の復旧記録を確認できません。次の変更を行う前に現在の航路を確認してください。';
}

class InMemoryRouteMutationJournalRepository
    implements RouteMutationJournalRepository {
  final Map<String, RouteMutationJournal> _entries = {};

  @override
  Future<RouteMutationJournal?> load(String ownerId, String questId) async =>
      _entries['$ownerId:$questId'];

  @override
  Future<void> save(RouteMutationJournal journal) async {
    _entries['${journal.ownerId}:${journal.questId}'] = journal;
  }

  @override
  Future<void> clear(String ownerId, String questId) async {
    _entries.remove('$ownerId:$questId');
  }
}

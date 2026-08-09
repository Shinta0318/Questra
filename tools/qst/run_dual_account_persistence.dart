import 'dart:convert';
import 'dart:io';
import 'dart:math';

const evidencePath = 'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml';

Future<void> main() async {
  final config = _Config.fromEnvironment();
  final projectRef = config.projectUrl.host.split('.').first;
  _requireProjectEvidence(projectRef);

  final ids = _TestIds.create();
  final siblingQuestId = _uuid();
  final siblingMissionId = _uuid();
  final taskRouteVersionId = _uuid();
  final taskRouteProposalId = _uuid();
  final taskRouteItemId = _uuid();
  final staleRouteVersionId = _uuid();
  final staleRouteProposalId = _uuid();
  final staleRouteItemId = _uuid();
  _Session? accountA;
  _Session? accountB;
  var questCreated = false;
  var taskCreated = false;
  var memoryCreated = false;
  var mediaCreated = false;
  var storageObjectCreated = false;
  var siblingQuestCreated = false;
  String? guildPublicationId;

  try {
    accountA = await _signIn(
      config,
      config.accountAEmail,
      config.accountAPassword,
    );
    accountB = await _signIn(
      config,
      config.accountBEmail,
      config.accountBPassword,
    );
    if (accountA.userId == accountB.userId) {
      throw StateError('Beta accounts A and B must be different users.');
    }

    await _expectOne(accountA, 'user_profiles', 'id', accountA.userId);
    await accountA.insert('quests', {
      'id': ids.quest,
      'owner_id': accountA.userId,
      'title': 'QST-162 persistence probe',
      'description': 'Automated Beta acceptance record',
      'status': 'active',
      'visibility': 'private',
    });
    questCreated = true;
    await accountA.insert('missions', {
      'id': ids.mission,
      'quest_id': ids.quest,
      'title': 'Verify persistence after re-login',
      'status': 'todo',
    });
    await accountA.insert('tasks', {
      'id': ids.task,
      'owner_id': accountA.userId,
      'quest_id': ids.quest,
      'mission_id': ids.mission,
      'title': 'Verify hosted Task persistence',
      'action': 'Reload this Task after a new session',
      'done_condition': 'The same Task row is visible after re-login',
      'status': 'pending',
      'required': true,
      'order_index': 0,
    });
    taskCreated = true;
    await accountA.expectArcTaskContext(
      questId: ids.quest,
      missionId: ids.mission,
      taskId: ids.task,
    );
    await accountA.insert('quests', {
      'id': siblingQuestId,
      'owner_id': accountA.userId,
      'title': 'QST-278 sibling hierarchy probe',
      'description': 'Cross-parent integrity record',
      'status': 'active',
      'visibility': 'private',
    });
    siblingQuestCreated = true;
    await accountA.insert('missions', {
      'id': siblingMissionId,
      'quest_id': siblingQuestId,
      'title': 'Sibling Mission for parent guard',
      'status': 'todo',
    });
    await accountA.insert('arc_memories', {
      'id': ids.memory,
      'user_id': accountA.userId,
      'quest_id': ids.quest,
      'mission_id': ids.mission,
      'title': 'QST-162 memory probe',
      'content': 'Automated Beta acceptance record',
      'source_type': 'arc_memory',
      'user_visible': true,
    });
    memoryCreated = true;

    await accountA.insert('trails', {
      'id': ids.trail,
      'owner_id': accountA.userId,
      'quest_id': ids.quest,
      'mission_id': ids.mission,
      'task_id': ids.task,
      'title': 'QST-199 private Trail probe',
      'summary': 'Automated Beta acceptance record',
      'content': 'Automated Beta acceptance record',
      'visibility': 'private',
      'trail_type': 'quest_record',
    });
    await accountA.insert('media', {
      'id': ids.media,
      'owner_id': accountA.userId,
      'bucket': 'trail-media',
      'path': '${accountA.userId}/${ids.storageObject}.txt',
      'media_type': 'image',
      'related_table': 'trails',
      'related_id': ids.trail,
      'visibility': 'private',
    });
    mediaCreated = true;
    await accountA.uploadTrailObject(
      '${accountA.userId}/${ids.storageObject}.txt',
      utf8.encode('QST-199 private media probe'),
    );
    storageObjectCreated = true;

    await accountA.insert('route_versions', {
      'id': ids.routeVersion,
      'quest_id': ids.quest,
      'version_number': 1,
      'status': 'proposed',
      'generated_by': 'arc',
      'generation_reason': 'QST-199 RLS proof',
    });
    await accountA.insert('route_change_proposals', {
      'id': ids.routeProposal,
      'quest_id': ids.quest,
      'route_version_id': ids.routeVersion,
      'proposal_type': 'replan',
      'summary': 'QST-199 private route proposal',
      'reason': 'Automated Beta acceptance record',
      'confidence_score': 0.8,
    });
    await accountA.insert('route_change_items', {
      'id': ids.routeItem,
      'proposal_id': ids.routeProposal,
      'action_type': 'pause',
      'target_mission_id': ids.mission,
      'title': 'Pause Mission for QST-196 proof',
      'reason': 'Automated Beta acceptance record',
      'safety_level': 2,
    });
    guildPublicationId = await accountA.publishGuildQuest(ids.quest);

    final firstAccountASession = accountA;
    accountA = await _signIn(
      config,
      config.accountAEmail,
      config.accountAPassword,
    );
    firstAccountASession.close();
    await _expectOne(accountA, 'user_profiles', 'id', accountA.userId);
    await _expectOne(accountA, 'quests', 'id', ids.quest);
    await _expectOne(accountA, 'missions', 'id', ids.mission);
    await accountA.expectFieldValue(
      'missions',
      'id',
      ids.mission,
      'quest_id',
      ids.quest,
    );
    await _expectOne(accountA, 'tasks', 'id', ids.task);
    await _expectOne(accountA, 'arc_memories', 'id', ids.memory);
    await _expectOne(accountA, 'trails', 'id', ids.trail);
    await _expectOne(accountA, 'media', 'id', ids.media);
    await _expectOne(accountA, 'route_versions', 'id', ids.routeVersion);
    await _expectOne(
      accountA,
      'route_change_proposals',
      'id',
      ids.routeProposal,
    );
    await accountA.expectTrailObjectReadable(
      '${accountA.userId}/${ids.storageObject}.txt',
    );

    await _expectNone(accountB, 'quests', 'id', ids.quest);
    await _expectNone(accountB, 'missions', 'id', ids.mission);
    await _expectNone(accountB, 'tasks', 'id', ids.task);
    await _expectNone(accountB, 'arc_memories', 'id', ids.memory);
    await _expectNone(accountB, 'trails', 'id', ids.trail);
    await _expectNone(accountB, 'media', 'id', ids.media);
    await _expectNone(accountB, 'route_versions', 'id', ids.routeVersion);
    await _expectNone(
      accountB,
      'route_change_proposals',
      'id',
      ids.routeProposal,
    );
    await _expectNone(
      accountB,
      'guild_quest_publications',
      'id',
      guildPublicationId,
    );
    await _expectNone(
      accountB,
      'guild_quest_publication_owners',
      'publication_id',
      guildPublicationId,
    );
    await accountB.expectTrailObjectDenied(
      '${accountA.userId}/${ids.storageObject}.txt',
    );
    await accountB.expectInsertDenied('route_versions', {
      'quest_id': ids.quest,
      'version_number': 99,
      'status': 'proposed',
      'generated_by': 'user',
      'generation_reason': 'Cross-account Route write must fail',
    });
    await accountB.expectInsertDenied('tasks', {
      'owner_id': accountB.userId,
      'quest_id': ids.quest,
      'mission_id': ids.mission,
      'title': 'Cross-account Task write must fail',
      'action': 'Attempt a write against another owner Mission',
      'done_condition': 'The database rejects this row',
      'status': 'pending',
    });
    await accountA.expectInsertDenied('tasks', {
      'owner_id': accountA.userId,
      'quest_id': ids.quest,
      'mission_id': siblingMissionId,
      'title': 'Cross-parent Task must fail',
      'action': 'Attempt to mix a Quest and Mission hierarchy',
      'done_condition': 'The database rejects this row',
      'status': 'pending',
    });
    await accountA.expectInsertDenied('trails', {
      'id': _uuid(),
      'owner_id': accountA.userId,
      'quest_id': ids.quest,
      'mission_id': siblingMissionId,
      'title': 'Cross-parent Trail must fail',
      'summary': 'Integrity probe',
      'content': 'Integrity probe',
      'visibility': 'private',
      'trail_type': 'mission_record',
    });
    await accountB.expectTaskExpansionDenied(
      questId: ids.quest,
      missionId: ids.mission,
      idempotencyKey: 'qst273-denied:${ids.task}',
    );
    await accountA.expectTaskExpansionReady(
      questId: ids.quest,
      missionId: ids.mission,
      idempotencyKey: 'qst273-owner:${ids.task}',
    );
    await accountB.expectRpcDenied('apply_route_change_proposal', {
      'p_proposal_id': ids.routeProposal,
      'p_accepted_item_ids': <String>[ids.routeItem],
      'p_expected_route_version_id': ids.routeVersion,
    });

    await accountA.applyRouteProposal(
      proposalId: ids.routeProposal,
      itemId: ids.routeItem,
      routeVersionId: ids.routeVersion,
    );
    await accountA.expectFieldValue(
      'missions',
      'id',
      ids.mission,
      'route_state',
      'paused',
    );
    await accountA.rollbackRouteProposal(ids.routeProposal);
    await accountA.expectFieldValue(
      'missions',
      'id',
      ids.mission,
      'route_state',
      'active',
    );
    await accountA.expectFieldValue(
      'route_change_proposals',
      'id',
      ids.routeProposal,
      'status',
      'rolledBack',
    );
    await accountA.insert('route_versions', {
      'id': staleRouteVersionId,
      'quest_id': ids.quest,
      'version_number': 100,
      'status': 'proposed',
      'generated_by': 'arc',
      'generation_reason': 'QST-286 stale route proof',
    });
    await accountA.insert('route_change_proposals', {
      'id': staleRouteProposalId,
      'quest_id': ids.quest,
      'route_version_id': staleRouteVersionId,
      'proposal_type': 'manualReview',
      'summary': 'This proposal must become stale after progress changes',
      'reason': 'manualReview',
      'confidence_score': 0.9,
    });
    await accountA.insert('route_change_items', {
      'id': staleRouteItemId,
      'proposal_id': staleRouteProposalId,
      'action_type': 'reorder',
      'target_mission_id': ids.mission,
      'target_task_id': ids.task,
      'title': 'Stale Task reorder must not apply',
      'reason': 'Hosted concurrent progress protection proof',
      'before_data': {'orderIndex': 0},
      'after_data': {'orderIndex': 7},
      'safety_level': 1,
    });
    await accountA.update('tasks', 'id', ids.task, {
      'scheduled_date': DateTime.now()
          .toUtc()
          .add(const Duration(days: 2))
          .toIso8601String()
          .substring(0, 10),
    });
    await accountA.expectStaleTaskRouteProposal(
      proposalId: staleRouteProposalId,
      itemId: staleRouteItemId,
      routeVersionId: staleRouteVersionId,
    );
    await accountA.expectFieldValue('tasks', 'id', ids.task, 'order_index', 0);
    await accountA.expectFieldValue(
      'route_change_proposals',
      'id',
      staleRouteProposalId,
      'status',
      'stale',
    );
    await accountA.insert('route_versions', {
      'id': taskRouteVersionId,
      'quest_id': ids.quest,
      'version_number': 99,
      'status': 'proposed',
      'generated_by': 'arc',
      'generation_reason': 'QST-279 Task route proof',
    });
    await accountA.insert('route_change_proposals', {
      'id': taskRouteProposalId,
      'quest_id': ids.quest,
      'route_version_id': taskRouteVersionId,
      'proposal_type': 'manualReview',
      'summary': 'Reorder one Task after approval',
      'reason': 'manualReview',
      'confidence_score': 0.9,
    });
    await accountA.insert('route_change_items', {
      'id': taskRouteItemId,
      'proposal_id': taskRouteProposalId,
      'action_type': 'reorder',
      'target_mission_id': ids.mission,
      'target_task_id': ids.task,
      'title': 'Move Task in the route',
      'reason': 'Hosted Task route transaction proof',
      'before_data': {'orderIndex': 0},
      'after_data': {'orderIndex': 5},
      'safety_level': 1,
    });
    await accountA.expectFieldValue('tasks', 'id', ids.task, 'order_index', 0);
    await accountA.applyTaskRouteProposal(
      proposalId: taskRouteProposalId,
      itemId: taskRouteItemId,
      routeVersionId: taskRouteVersionId,
    );
    await accountA.expectFieldValue('tasks', 'id', ids.task, 'order_index', 5);
    await accountA.rollbackTaskRouteProposal(taskRouteProposalId);
    await accountA.expectFieldValue('tasks', 'id', ids.task, 'order_index', 0);
    await accountA.expectFieldValue(
      'route_change_proposals',
      'id',
      taskRouteProposalId,
      'status',
      'rolledBack',
    );
    await accountA.expectRpcDenied('confirm_mission_outcome', {
      'p_mission_id': ids.mission,
    });
    await accountA.expectUpdateDenied('missions', 'id', ids.mission, {
      'status': 'completed',
      'success_confirmed_at': DateTime.now().toUtc().toIso8601String(),
    });
    await accountA.update('tasks', 'id', ids.task, {'status': 'completed'});
    await accountA.update('tasks', 'id', ids.task, {'status': 'completed'});
    final completionEvents = await accountA.countWhere('task_progress_events', {
      'task_id': 'eq.${ids.task}',
      'event_name': 'eq.task_completed',
    });
    if (completionEvents != 1) {
      throw StateError('Task completion retry created duplicate events.');
    }
    await accountA.confirmMissionOutcome(ids.mission);
    await accountA.expectFieldValue(
      'missions',
      'id',
      ids.mission,
      'status',
      'completed',
    );

    final anonymous = _Session(
      config,
      HttpClient(),
      config.anonKey,
      'anonymous',
    );
    try {
      await anonymous.expectReadDenied('quests', 'id', ids.quest);
      await anonymous.expectReadDenied(
        'route_versions',
        'id',
        ids.routeVersion,
      );
      await anonymous.expectReadDenied(
        'guild_quest_publications',
        'id',
        guildPublicationId,
      );
      await anonymous.expectTrailObjectDenied(
        '${accountA.userId}/${ids.storageObject}.txt',
      );
    } finally {
      anonymous.close();
    }

    await accountA.unpublishGuildQuest(guildPublicationId);
    guildPublicationId = null;
    await accountA.deleteTrailObject(
      '${accountA.userId}/${ids.storageObject}.txt',
    );
    storageObjectCreated = false;
    await accountA.delete('media', 'id', ids.media);
    mediaCreated = false;

    await accountA.delete('arc_memories', 'id', ids.memory);
    memoryCreated = false;
    await accountA.delete('tasks', 'id', ids.task);
    taskCreated = false;
    await accountA.delete('quests', 'id', ids.quest);
    questCreated = false;
    await accountA.delete('quests', 'id', siblingQuestId);
    siblingQuestCreated = false;
    await _writeEvidence(projectRef);
    stdout.writeln('Dual-account persistence acceptance passed.');
    stdout.writeln('Sanitized evidence written to $evidencePath');
  } finally {
    if (accountA != null) {
      if (memoryCreated) {
        await accountA.delete('arc_memories', 'id', ids.memory);
      }
      if (guildPublicationId != null) {
        await accountA.unpublishGuildQuest(guildPublicationId);
      }
      if (storageObjectCreated) {
        await accountA.deleteTrailObject(
          '${accountA.userId}/${ids.storageObject}.txt',
        );
      }
      if (mediaCreated) {
        await accountA.delete('media', 'id', ids.media);
      }
      if (taskCreated) {
        await accountA.delete('tasks', 'id', ids.task);
      }
      if (questCreated) {
        await accountA.delete('quests', 'id', ids.quest);
      }
      if (siblingQuestCreated) {
        await accountA.delete('quests', 'id', siblingQuestId);
      }
      accountA.close();
    }
    accountB?.close();
  }
}

Future<_Session> _signIn(_Config config, String email, String password) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      config.projectUrl.resolve('/auth/v1/token?grant_type=password'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set('apikey', config.anonKey);
    request.write(jsonEncode({'email': email, 'password': password}));
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode != 200) {
      throw HttpException(
        'Beta account login failed (${response.statusCode}).',
      );
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    final userId = user?['id'] as String?;
    if (token == null || userId == null) {
      throw const FormatException('Auth response did not include a session.');
    }
    return _Session(config, client, token, userId);
  } catch (_) {
    client.close(force: true);
    rethrow;
  }
}

Future<void> _expectOne(
  _Session session,
  String table,
  String field,
  String value,
) async {
  final rows = await session.find(table, field, value);
  if (rows.length != 1) {
    throw StateError('$table persistence check expected one row.');
  }
}

Future<void> _expectNone(
  _Session session,
  String table,
  String field,
  String value,
) async {
  final rows = await session.find(table, field, value);
  if (rows.isNotEmpty) {
    throw StateError('$table cross-account isolation failed.');
  }
}

void _requireProjectEvidence(String projectRef) {
  final file = File('docs/qst/BETA_RLS_EVIDENCE.yaml');
  if (!file.existsSync()) throw StateError('Cloud RLS evidence is missing.');
  final evidence = file.readAsStringSync().replaceAll('\r\n', '\n');
  if (!evidence.contains('project_ref: "$projectRef"') ||
      !evidence.contains('rls_behavior:\n  status: passed')) {
    throw StateError('Cloud RLS evidence does not match the target project.');
  }
}

Future<void> _writeEvidence(String projectRef) async {
  final commitResult = await Process.run('git', ['rev-parse', 'HEAD']);
  final commit = (commitResult.stdout as String).trim();
  if (commitResult.exitCode != 0 ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    throw StateError('Unable to resolve source commit at execution.');
  }
  final statusResult = await Process.run('git', ['status', '--porcelain']);
  final workingTreeClean = (statusResult.stdout as String).trim().isEmpty;
  final now = DateTime.now().toUtc().toIso8601String();
  File(evidencePath).writeAsStringSync('''version: 3
status: verified
updated_at_utc: "$now"
source_commit_at_execution: "$commit"
working_tree_clean_at_execution: $workingTreeClean
project_ref: "$projectRef"
acceptance:
  account_a_profile_after_relogin: passed
  account_a_quest_after_relogin: passed
  account_a_mission_after_relogin: passed
  account_a_task_after_relogin: passed
  account_a_arc_memory_after_relogin: passed
  account_a_trail_after_relogin: passed
  account_a_media_after_relogin: passed
  account_a_route_after_relogin: passed
  account_a_storage_object_read: passed
  account_b_private_quest_visibility: denied
  account_b_private_mission_visibility: denied
  account_b_private_task_visibility: denied
  account_b_private_task_write: denied
  account_b_task_expansion: denied
  account_a_task_expansion: passed
  account_a_cross_parent_task_write: denied
  account_a_cross_parent_trail_write: denied
  account_a_incomplete_mission_confirmation: denied
  account_a_direct_mission_completion: denied
  account_a_mission_completion_rpc: passed
  task_completion_retry_event_count: 1
  task_route_unchanged_before_approval: passed
  task_route_apply_transaction: passed
  task_route_rollback_restore: passed
  arc_chat_task_context: passed
  stale_route_conflict_rejected: passed
  stale_route_task_unchanged: passed
  account_b_private_arc_memory_visibility: denied
  account_b_private_trail_visibility: denied
  account_b_private_media_visibility: denied
  account_b_private_route_visibility: denied
  account_b_private_route_write: denied
  account_b_private_storage_object_read: denied
  account_b_pending_guild_publication_visibility: denied
  account_b_guild_owner_mapping_visibility: denied
  account_b_route_apply_rpc: denied
  account_a_route_apply_after_relogin: passed
  account_a_route_rollback_restore: passed
  anonymous_private_quest_visibility: denied
  anonymous_private_route_visibility: denied
  anonymous_private_storage_object_read: denied
  anonymous_pending_guild_publication_visibility: denied
  test_records_cleaned: true
guardrails:
  credential_values_recorded: false
  anon_key_recorded: false
  account_emails_recorded: false
  private_journey_content_recorded: false
  local_fallback_is_cloud_evidence: false
''');
}

class _Session {
  _Session(this.config, this.client, this.token, this.userId);

  final _Config config;
  final HttpClient client;
  final String token;
  final String userId;

  Future<void> insert(String table, Map<String, Object?> row) async {
    await _request('POST', table, body: row, expectedStatuses: {201});
  }

  Future<List<dynamic>> find(String table, String field, String value) async {
    final body = await _request(
      'GET',
      table,
      query: {'select': field, field: 'eq.$value'},
      expectedStatuses: {200},
    );
    return jsonDecode(body) as List<dynamic>;
  }

  Future<void> delete(String table, String field, String value) async {
    await _request(
      'DELETE',
      table,
      query: {field: 'eq.$value'},
      expectedStatuses: {204},
    );
  }

  Future<void> update(
    String table,
    String field,
    String value,
    Map<String, Object?> values,
  ) async {
    await _request(
      'PATCH',
      table,
      query: {field: 'eq.$value'},
      body: values,
      expectedStatuses: {204},
    );
  }

  Future<void> expectInsertDenied(
    String table,
    Map<String, Object?> row,
  ) async {
    await _request('POST', table, body: row, expectedStatuses: {400, 401, 403});
  }

  Future<void> expectUpdateDenied(
    String table,
    String field,
    String value,
    Map<String, Object?> values,
  ) async {
    await _request(
      'PATCH',
      table,
      query: {field: 'eq.$value'},
      body: values,
      expectedStatuses: {400, 401, 403},
    );
  }

  Future<int> countWhere(String table, Map<String, String> filters) async {
    final body = await _request(
      'GET',
      table,
      query: {'select': 'id', ...filters},
      expectedStatuses: {200},
    );
    return (jsonDecode(body) as List<dynamic>).length;
  }

  Future<void> expectTaskExpansionReady({
    required String questId,
    required String missionId,
    required String idempotencyKey,
  }) async {
    final body = await _functionRequest(
      'quest-planning-v2',
      body: {
        'mode': 'expand_tasks',
        'quest_id': questId,
        'mission_id': missionId,
        'idempotency_key': idempotencyKey,
      },
      expectedStatuses: {200},
    );
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final plan = decoded['task_plan'];
    if (decoded['status'] != 'preview_ready' ||
        plan is! Map<String, dynamic> ||
        plan['tasks'] is! List ||
        (plan['tasks'] as List).isEmpty) {
      throw StateError('Hosted Task expansion did not return a valid preview.');
    }
  }

  Future<void> expectArcTaskContext({
    required String questId,
    required String missionId,
    required String taskId,
  }) async {
    final raw = await _functionRequest(
      'arc-chat',
      body: {
        'message': '次に実行するTaskを教えて',
        'history': const [],
        'context': {
          'active_quests': [
            {'id': questId, 'title': 'QST Arc context probe'},
          ],
          'recent_missions': [
            {
              'id': missionId,
              'quest_id': questId,
              'title': 'Hosted Mission context',
            },
          ],
          'recent_tasks': [
            {
              'id': taskId,
              'quest_id': questId,
              'mission_id': missionId,
              'title': 'Verify hosted Task persistence',
              'action': 'Reload this Task after a new session',
              'done_condition': 'The same Task row is visible after re-login',
              'status': 'pending',
            },
          ],
          'recent_trails': const [],
          'memories': const [],
        },
      },
      expectedStatuses: {200},
    );
    final response = jsonDecode(raw) as Map<String, dynamic>;
    final usage = response['context_usage'] as Map<String, dynamic>?;
    if (usage?['task_count'] != 1 || usage?['focused_task_id'] != taskId) {
      throw StateError('Arc Chat did not accept the owner Task context.');
    }
    if ((response['message'] as String?)?.trim().isEmpty ?? true) {
      throw StateError('Arc Chat returned no message for Task context.');
    }
  }

  Future<void> expectTaskExpansionDenied({
    required String questId,
    required String missionId,
    required String idempotencyKey,
  }) async {
    await _functionRequest(
      'quest-planning-v2',
      body: {
        'mode': 'expand_tasks',
        'quest_id': questId,
        'mission_id': missionId,
        'idempotency_key': idempotencyKey,
      },
      expectedStatuses: {404},
    );
  }

  Future<String> publishGuildQuest(String questId) async {
    final body = await _rpc('publish_guild_quest', {
      'p_quest_id': questId,
      'p_summary': 'QST-199 pending Guild publication',
      'p_tags': <String>['qst-199'],
      'p_visibility': 'public',
      'p_seeking_companions': false,
    });
    final id = jsonDecode(body) as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Guild publication RPC did not return an id.');
    }
    return id;
  }

  Future<void> unpublishGuildQuest(String publicationId) async {
    await _rpc('unpublish_guild_quest', {'p_publication_id': publicationId});
  }

  Future<String> _rpc(String function, Map<String, Object?> body) {
    return _request(
      'POST',
      'rpc/$function',
      body: body,
      expectedStatuses: {200, 204},
    );
  }

  Future<void> expectReadDenied(
    String table,
    String field,
    String value,
  ) async {
    final body = await _request(
      'GET',
      table,
      query: {'select': field, field: 'eq.$value'},
      expectedStatuses: {200, 401, 403},
    );
    if (body.isNotEmpty && body != '[]') {
      final decoded = jsonDecode(body);
      if (decoded is List && decoded.isNotEmpty) {
        throw StateError('$table anonymous visibility was not denied.');
      }
    }
  }

  Future<void> expectRpcDenied(
    String function,
    Map<String, Object?> body,
  ) async {
    await _request(
      'POST',
      'rpc/$function',
      body: body,
      expectedStatuses: {400, 401, 403, 404},
    );
  }

  Future<void> applyRouteProposal({
    required String proposalId,
    required String itemId,
    required String routeVersionId,
  }) async {
    await _rpc('apply_route_change_proposal', {
      'p_proposal_id': proposalId,
      'p_accepted_item_ids': <String>[itemId],
      'p_expected_route_version_id': routeVersionId,
    });
  }

  Future<void> rollbackRouteProposal(String proposalId) async {
    await _rpc('rollback_route_change_proposal', {'p_proposal_id': proposalId});
  }

  Future<void> applyTaskRouteProposal({
    required String proposalId,
    required String itemId,
    required String routeVersionId,
  }) async {
    await _rpc('apply_task_aware_route_change_proposal', {
      'p_proposal_id': proposalId,
      'p_accepted_item_ids': <String>[itemId],
      'p_expected_route_version_id': routeVersionId,
    });
  }

  Future<void> expectStaleTaskRouteProposal({
    required String proposalId,
    required String itemId,
    required String routeVersionId,
  }) async {
    final body = await _rpc('apply_task_aware_route_change_proposal', {
      'p_proposal_id': proposalId,
      'p_accepted_item_ids': <String>[itemId],
      'p_expected_route_version_id': routeVersionId,
    });
    final result = jsonDecode(body) as Map<String, dynamic>;
    if (result['status'] != 'stale' ||
        result['stale_reason'] != 'route_state_changed_after_proposal' ||
        result['conflict_snapshot'] is! Map) {
      throw StateError('Stale route proposal was not rejected safely.');
    }
  }

  Future<void> rollbackTaskRouteProposal(String proposalId) async {
    await _rpc('rollback_task_aware_route_change_proposal', {
      'p_proposal_id': proposalId,
    });
  }

  Future<void> confirmMissionOutcome(String missionId) async {
    await _rpc('confirm_mission_outcome', {'p_mission_id': missionId});
  }

  Future<void> expectFieldValue(
    String table,
    String idField,
    String id,
    String field,
    Object expected,
  ) async {
    final body = await _request(
      'GET',
      table,
      query: {'select': field, idField: 'eq.$id'},
      expectedStatuses: {200},
    );
    final rows = jsonDecode(body) as List<dynamic>;
    if (rows.length != 1 ||
        (rows.single as Map<String, dynamic>)[field] != expected) {
      throw StateError('$table.$field did not equal the expected value.');
    }
  }

  Future<void> uploadTrailObject(String path, List<int> bytes) async {
    await _storageRequest('POST', path, bytes: bytes, expectedStatuses: {200});
  }

  Future<void> expectTrailObjectReadable(String path) async {
    await _storageRequest('GET', path, expectedStatuses: {200});
  }

  Future<void> expectTrailObjectDenied(String path) async {
    await _storageRequest('GET', path, expectedStatuses: {400, 401, 403, 404});
  }

  Future<void> deleteTrailObject(String path) async {
    await _storageRequest('DELETE', path, expectedStatuses: {200});
  }

  Future<void> _storageRequest(
    String method,
    String path, {
    List<int>? bytes,
    required Set<int> expectedStatuses,
  }) async {
    final uri = config.projectUrl.resolve(
      '/storage/v1/object/trail-media/${Uri.encodeFull(path)}',
    );
    final request = await client.openUrl(method, uri);
    request.headers.set('apikey', config.anonKey);
    request.headers.set('Authorization', 'Bearer $token');
    request.headers.contentType = ContentType.binary;
    if (bytes != null) request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    if (!expectedStatuses.contains(response.statusCode)) {
      throw HttpException('Storage $method failed (${response.statusCode}).');
    }
  }

  Future<String> _request(
    String method,
    String table, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    required Set<int> expectedStatuses,
  }) async {
    final uri = config.projectUrl
        .resolve('/rest/v1/$table')
        .replace(queryParameters: query);
    final request = await client.openUrl(method, uri);
    request.headers.contentType = ContentType.json;
    request.headers.set('apikey', config.anonKey);
    request.headers.set('Authorization', 'Bearer $token');
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    if (!expectedStatuses.contains(response.statusCode)) {
      final detail = responseBody.replaceAll(RegExp(r'\s+'), ' ').trim();
      final safeDetail = detail.length > 400
          ? detail.substring(0, 400)
          : detail;
      throw HttpException(
        '$table $method failed (${response.statusCode}): $safeDetail',
      );
    }
    return responseBody;
  }

  Future<String> _functionRequest(
    String function, {
    required Map<String, Object?> body,
    required Set<int> expectedStatuses,
  }) async {
    final uri = config.projectUrl.resolve('/functions/v1/$function');
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set('apikey', config.anonKey);
    request.headers.set('Authorization', 'Bearer $token');
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    if (!expectedStatuses.contains(response.statusCode)) {
      final detail = responseBody.replaceAll(RegExp(r'\s+'), ' ').trim();
      final safeDetail = detail.length > 400
          ? detail.substring(0, 400)
          : detail;
      throw HttpException(
        '$function failed (${response.statusCode}): $safeDetail',
      );
    }
    return responseBody;
  }

  void close() => client.close(force: true);
}

class _Config {
  const _Config(
    this.projectUrl,
    this.anonKey,
    this.accountAEmail,
    this.accountAPassword,
    this.accountBEmail,
    this.accountBPassword,
  );

  factory _Config.fromEnvironment() {
    String required(String name) {
      final value = Platform.environment[name]?.trim();
      if (value == null || value.isEmpty) {
        throw StateError('Required environment variable is missing: $name');
      }
      return value;
    }

    final url = Uri.parse(required('SUPABASE_URL'));
    if (url.scheme != 'https' || !url.host.endsWith('.supabase.co')) {
      throw StateError('SUPABASE_URL must be a hosted HTTPS Supabase URL.');
    }
    return _Config(
      url,
      required('SUPABASE_ANON_KEY'),
      required('QST_BETA_ACCOUNT_A_EMAIL'),
      required('QST_BETA_ACCOUNT_A_PASSWORD'),
      required('QST_BETA_ACCOUNT_B_EMAIL'),
      required('QST_BETA_ACCOUNT_B_PASSWORD'),
    );
  }

  final Uri projectUrl;
  final String anonKey;
  final String accountAEmail;
  final String accountAPassword;
  final String accountBEmail;
  final String accountBPassword;
}

class _TestIds {
  const _TestIds(
    this.quest,
    this.mission,
    this.task,
    this.memory,
    this.trail,
    this.media,
    this.storageObject,
    this.routeVersion,
    this.routeProposal,
    this.routeItem,
  );

  factory _TestIds.create() => _TestIds(
    _uuid(),
    _uuid(),
    _uuid(),
    _uuid(),
    _uuid(),
    _uuid(),
    _uuid(),
    _uuid(),
    _uuid(),
    _uuid(),
  );

  final String quest;
  final String mission;
  final String task;
  final String memory;
  final String trail;
  final String media;
  final String storageObject;
  final String routeVersion;
  final String routeProposal;
  final String routeItem;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

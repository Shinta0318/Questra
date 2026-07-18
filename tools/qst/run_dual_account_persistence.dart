import 'dart:convert';
import 'dart:io';
import 'dart:math';

const evidencePath = 'docs/qst/BETA_DUAL_ACCOUNT_PERSISTENCE.yaml';

Future<void> main() async {
  final config = _Config.fromEnvironment();
  final projectRef = config.projectUrl.host.split('.').first;
  _requireProjectEvidence(projectRef);

  final ids = _TestIds.create();
  _Session? accountA;
  _Session? accountB;
  var questCreated = false;
  var memoryCreated = false;

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
    await _expectOne(accountA, 'arc_memories', 'id', ids.memory);

    await _expectNone(accountB, 'quests', 'id', ids.quest);
    await _expectNone(accountB, 'missions', 'id', ids.mission);
    await _expectNone(accountB, 'arc_memories', 'id', ids.memory);

    await accountA.delete('arc_memories', 'id', ids.memory);
    memoryCreated = false;
    await accountA.delete('quests', 'id', ids.quest);
    questCreated = false;
    await _writeEvidence(projectRef);
    stdout.writeln('Dual-account persistence acceptance passed.');
    stdout.writeln('Sanitized evidence written to $evidencePath');
  } finally {
    if (accountA != null) {
      if (memoryCreated) {
        await accountA.delete('arc_memories', 'id', ids.memory);
      }
      if (questCreated) {
        await accountA.delete('quests', 'id', ids.quest);
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
    throw StateError('Unable to resolve candidate source commit.');
  }
  final now = DateTime.now().toUtc().toIso8601String();
  File(evidencePath).writeAsStringSync('''version: 1
status: verified
updated_at_utc: "$now"
candidate_source_commit: "$commit"
project_ref: "$projectRef"
acceptance:
  account_a_profile_after_relogin: passed
  account_a_quest_after_relogin: passed
  account_a_mission_after_relogin: passed
  account_a_arc_memory_after_relogin: passed
  account_b_private_quest_visibility: denied
  account_b_private_mission_visibility: denied
  account_b_private_arc_memory_visibility: denied
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
      query: {'select': 'id', field: 'eq.$value'},
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
      throw HttpException('$table $method failed (${response.statusCode}).');
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
  const _TestIds(this.quest, this.mission, this.memory);

  factory _TestIds.create() => _TestIds(_uuid(), _uuid(), _uuid());

  final String quest;
  final String mission;
  final String memory;
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

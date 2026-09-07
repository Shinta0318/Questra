import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final options = <String, String>{};
  for (final argument in arguments.where((value) => value.startsWith('--'))) {
    final separator = argument.indexOf('=');
    if (separator > 2) {
      options[argument.substring(2, separator)] = argument.substring(
        separator + 1,
      );
    }
  }
  final action = options['action'];
  if (action == null) _fail(_usage);
  final url = Platform.environment['SUPABASE_URL'];
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'];
  final operatorJwt = Platform.environment['QST_GUILD_OPERATOR_JWT'];
  if ([
    url,
    anonKey,
    operatorJwt,
  ].any((value) => value == null || value.isEmpty)) {
    _fail(
      'SUPABASE_URL, SUPABASE_ANON_KEY, and QST_GUILD_OPERATOR_JWT are required.',
    );
  }

  final request = switch (action) {
    'metrics' => ('get_guild_pilot_metrics', <String, Object?>{}),
    'member' => (
      'set_guild_pilot_member',
      <String, Object?>{
        'p_user_id': _required(options, 'user-id'),
        'p_enabled': _required(options, 'enabled') == 'true',
        'p_cohort': options['cohort'] ?? 'internal_beta',
        'p_reason_code': _required(options, 'reason-code'),
      },
    ),
    'publication' => (
      'resolve_guild_publication_moderation',
      <String, Object?>{
        'p_publication_id': _required(options, 'publication-id'),
        'p_approved': _required(options, 'approved') == 'true',
        'p_reason_code': _required(options, 'reason-code'),
      },
    ),
    'appeal' => (
      'resolve_guild_moderation_appeal',
      <String, Object?>{
        'p_appeal_id': _required(options, 'appeal-id'),
        'p_accepted': _required(options, 'accepted') == 'true',
        'p_reason_code': _required(options, 'reason-code'),
      },
    ),
    _ => _fail<(String, Map<String, Object?>)>(_usage),
  };

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final uri = Uri.parse('${url!}/rest/v1/rpc/${request.$1}');
    final httpRequest = await client.postUrl(uri);
    httpRequest.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $operatorJwt')
      ..set('apikey', anonKey!)
      ..set(HttpHeaders.contentTypeHeader, 'application/json');
    httpRequest.write(jsonEncode(request.$2));
    final response = await httpRequest.close().timeout(
      const Duration(seconds: 30),
    );
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail('Guild Pilot operation failed (${response.statusCode}).');
    }
    if (action == 'metrics') {
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(jsonDecode(body)),
      );
    } else {
      stdout.writeln('Guild Pilot operation completed.');
    }
  } finally {
    client.close(force: true);
  }
}

String _required(Map<String, String> options, String key) {
  final value = options[key];
  if (value == null || value.trim().isEmpty) _fail('Missing --$key.');
  return value;
}

Never _fail<T>(String message) {
  stderr.writeln(message);
  exit(2);
}

const _usage = '''
Usage:
  dart run tools/qst/guild_pilot_operator.dart --action=metrics
  dart run tools/qst/guild_pilot_operator.dart --action=member --user-id=<uuid> --enabled=true --cohort=internal_beta --reason-code=<code>
  dart run tools/qst/guild_pilot_operator.dart --action=publication --publication-id=<uuid> --approved=true --reason-code=<code>
  dart run tools/qst/guild_pilot_operator.dart --action=appeal --appeal-id=<uuid> --accepted=true --reason-code=<code>
''';

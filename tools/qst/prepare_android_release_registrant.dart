import 'dart:convert';
import 'dart:io';

const _pluginMetadataPath = 'apps/mobile/.flutter-plugins-dependencies';
const _registrantPath =
    'apps/mobile/android/app/src/main/java/io/flutter/plugins/'
    'GeneratedPluginRegistrant.java';

void main() {
  final metadataFile = File(_pluginMetadataPath);
  final registrantFile = File(_registrantPath);

  if (!metadataFile.existsSync()) {
    _fail('Missing $_pluginMetadataPath. Run flutter pub get first.');
  }
  if (!registrantFile.existsSync()) {
    _fail('Missing $_registrantPath. Run flutter pub get first.');
  }

  final metadata = jsonDecode(metadataFile.readAsStringSync());
  final plugins = metadata['plugins'] as Map<String, dynamic>?;
  final androidPlugins = plugins?['android'] as List<dynamic>? ?? const [];
  final devPluginNames = androidPlugins
      .whereType<Map<String, dynamic>>()
      .where((plugin) => plugin['dev_dependency'] == true)
      .map((plugin) => plugin['name'] as String?)
      .whereType<String>()
      .toSet();

  if (devPluginNames.isEmpty) {
    stdout.writeln('No Android dev-dependency plugins require exclusion.');
    return;
  }

  final lines = registrantFile.readAsLinesSync();
  final output = <String>[];
  final removed = <String>{};

  for (var index = 0; index < lines.length;) {
    if (lines[index].trim() != 'try {') {
      output.add(lines[index]);
      index++;
      continue;
    }

    final blockEnd = _findRegistrationBlockEnd(lines, index);
    if (blockEnd == null) {
      output.add(lines[index]);
      index++;
      continue;
    }

    final block = lines.sublist(index, blockEnd + 1);
    final pluginName = _registeredPluginName(block);
    if (pluginName != null && devPluginNames.contains(pluginName)) {
      removed.add(pluginName);
    } else {
      output.addAll(block);
    }
    index = blockEnd + 1;
  }

  final stillRegistered = devPluginNames.where((pluginName) {
    return output.any(
      (line) => line.contains('Error registering plugin $pluginName,'),
    );
  }).toList();
  if (stillRegistered.isNotEmpty) {
    _fail(
      'Could not exclude Android dev-dependency plugins: '
      '${stillRegistered.join(', ')}',
    );
  }

  if (removed.isEmpty) {
    stdout.writeln('No dev-dependency registrations were present.');
    return;
  }

  registrantFile.writeAsStringSync('${output.join('\n')}\n');
  stdout.writeln(
    'Excluded test-only Android plugins from the release registrant: '
    '${removed.join(', ')}',
  );
}

int? _findRegistrationBlockEnd(List<String> lines, int start) {
  var sawCatch = false;
  final limit = (start + 12).clamp(0, lines.length);
  for (var index = start + 1; index < limit; index++) {
    if (lines[index].contains('catch (Exception e)')) {
      sawCatch = true;
    }
    if (sawCatch && lines[index].trim() == '}') {
      return index;
    }
  }
  return null;
}

String? _registeredPluginName(List<String> block) {
  final pattern = RegExp(r'Error registering plugin ([^,]+),');
  for (final line in block) {
    final match = pattern.firstMatch(line);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evaluation builder defines four context variants per seed', () {
    final root = Directory.current.parent.parent;
    final script = File('${root.path}/tools/qst/build_quest_planning_eval_200.ps1').readAsStringSync();
    expect(script, contains('beginner'));
    expect(script, contains('busy'));
    expect(script, contains('low_budget'));
    expect(script, contains('experienced'));
    expect(script, contains('200'));
  });
}

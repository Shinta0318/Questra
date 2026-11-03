import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/planning_context.dart';
import 'package:questra/features/quest/planning_preferences.dart';
import 'package:questra/features/quest/planning_preferences_repository.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('local planning consent and preferences stay account-scoped', () async {
    final repository = PersistedPlanningPreferencesRepository();
    const first = PlanningPreferences(
      context: PlanningContext(
        budgetLabel: 'private budget',
        consentGranted: true,
      ),
    );
    await repository.save(first, userId: 'account-a');

    expect(
      (await repository.load(userId: 'account-a'))?.context.budgetLabel,
      'private budget',
    );
    expect(await repository.load(userId: 'account-b'), isNull);
    expect(await repository.load(), isNull);
  });

  test(
    'ownerless legacy settings are not assigned to a signed-in account',
    () async {
      const legacy = PlanningPreferences(
        context: PlanningContext(
          budgetLabel: 'legacy private budget',
          consentGranted: true,
        ),
      );
      FlutterSecureStorage.setMockInitialValues({
        'questra_planning_preferences_v1': jsonEncode(legacy.toJson()),
      });
      final repository = PersistedPlanningPreferencesRepository();

      expect(await repository.load(userId: 'account-b'), isNull);
      expect(await repository.load(), isNull);
    },
  );
}

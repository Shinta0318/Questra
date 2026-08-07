import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'planning_preferences.dart';
import 'planning_preferences_repository.dart';

final planningPreferencesControllerProvider =
    NotifierProvider<PlanningPreferencesController, PlanningPreferences>(
      PlanningPreferencesController.new,
    );

class PlanningPreferencesController extends Notifier<PlanningPreferences> {
  int _loadGeneration = 0;

  @override
  PlanningPreferences build() {
    final userId = ref.watch(
      authControllerProvider.select((auth) => auth.profile?.id),
    );
    final generation = ++_loadGeneration;
    unawaited(Future<void>.microtask(() => _hydrate(userId, generation)));
    return const PlanningPreferences();
  }

  Future<void> apply(PlanningPreferences value) async {
    state = value;
    await ref
        .read(planningPreferencesRepositoryProvider)
        .save(value, userId: ref.read(authControllerProvider).profile?.id);
  }

  Future<void> _hydrate(String? userId, int generation) async {
    final loaded = await ref
        .read(planningPreferencesRepositoryProvider)
        .load(userId: userId);
    if (generation != _loadGeneration || loaded == null) return;
    state = loaded;
  }
}

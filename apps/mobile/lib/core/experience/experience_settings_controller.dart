import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import 'experience_settings.dart';
import 'experience_settings_repository.dart';

final experienceSettingsControllerProvider =
    NotifierProvider<ExperienceSettingsController, ExperienceSettings>(
  ExperienceSettingsController.new,
);

class ExperienceSettingsController extends Notifier<ExperienceSettings> {
  int _loadGeneration = 0;

  @override
  ExperienceSettings build() {
    final userId = ref.watch(
      authControllerProvider.select((auth) => auth.profile?.id),
    );
    final generation = ++_loadGeneration;
    unawaited(Future<void>.microtask(() => _hydrate(userId, generation)));
    return const ExperienceSettings();
  }

  Future<void> apply(ExperienceSettings settings) async {
    state = settings;
    await ref.read(experienceSettingsRepositoryProvider).save(
          settings,
          userId: ref.read(authControllerProvider).profile?.id,
        );
  }

  Future<void> applyPreset(ExperiencePreset preset) {
    return apply(ExperienceSettings.fromPreset(preset));
  }

  Future<void> _hydrate(String? userId, int generation) async {
    final loaded = await ref
        .read(experienceSettingsRepositoryProvider)
        .load(userId: userId);
    if (generation != _loadGeneration || loaded == null) return;
    state = loaded;
  }
}

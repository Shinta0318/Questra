// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Questra';

  @override
  String get home => 'Home';

  @override
  String get quest => 'Quest';

  @override
  String get trail => 'Trail';

  @override
  String get guild => 'Guild';

  @override
  String get profile => 'Profile';

  @override
  String get arc => 'Arc';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesBody => 'Your unsaved changes will be lost.';

  @override
  String get continueEditing => 'Keep editing';

  @override
  String get discardAndClose => 'Discard and close';

  @override
  String get requiredField => 'Required';

  @override
  String get profileCompact => 'You';

  @override
  String get trailEmptyTitle => 'No Trails yet';

  @override
  String get trailEmptyMessage =>
      'Capture today\'s progress, even if it is only a few words.';

  @override
  String get createFirstTrail => 'Create your first Trail';

  @override
  String get createTrail => 'Create Trail';

  @override
  String get trailHistoryTitle => 'Your Trails';

  @override
  String get trailHistoryDescription =>
      'Look back on your journey one day at a time.';

  @override
  String trailCount(int count) => '$count Trails';

  @override
  String get reflection => 'Reflections';

  @override
  String get starCandidate => 'Memory candidates';

  @override
  String get image => 'Images';

  @override
  String questContext(String title) => 'Quest: $title';

  @override
  String missionContext(String title) => 'Mission: $title';

  @override
  String taskContext(String title) => 'Task: $title';

  @override
  String starMemoryCandidate(String reason) => 'Memory candidate: $reason';

  @override
  String get trailTypeQuest => 'Quest update';

  @override
  String get trailTypeMission => 'Mission update';

  @override
  String get trailTypeArcReflection => 'Reflection with Arc';

  @override
  String get trailTypeManual => 'Personal note';
}

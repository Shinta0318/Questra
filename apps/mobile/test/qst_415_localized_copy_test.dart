import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trail/trail_timeline_widget.dart';
import 'package:questra/l10n/app_localizations.dart';
import 'package:questra/widgets/forms/questra_field_label.dart';
import 'package:questra/widgets/navigation/questra_bottom_navigation.dart';

void main() {
  testWidgets('major journey controls use Japanese copy', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('ja'),
        child: Scaffold(
          body: const QuestraFieldLabel(
            label: 'Questの名前',
            required: true,
            child: TextField(),
          ),
          bottomNavigationBar: QuestraBottomNavigation(
            currentIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('必須'), findsOneWidget);
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('自分'), findsOneWidget);
    expect(find.text('You'), findsNothing);
  });

  testWidgets('major journey controls use English copy', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: Scaffold(
          body: const QuestraFieldLabel(
            label: 'Quest name',
            required: true,
            child: TextField(),
          ),
          bottomNavigationBar: QuestraBottomNavigation(
            currentIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('自分'), findsNothing);
  });

  testWidgets('Trail empty state follows locale and keeps one action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('en'),
        child: Scaffold(
          body: TrailTimelineWidget(
            trails: const [],
            attachments: const {},
            onCreateTrail: () {},
          ),
        ),
      ),
    );

    expect(find.text('No Trails yet'), findsOneWidget);
    expect(find.text('Create your first Trail'), findsOneWidget);
    expect(find.text('まだTrailはありません'), findsNothing);
    expect(find.byKey(const ValueKey('trail-primary-create')), findsOneWidget);
  });

  testWidgets('external field name has one explicit semantic heading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('ja'),
        child: const Scaffold(
          body: QuestraFieldLabel(
            label: '叶えたい理由',
            helper: 'きっかけを書いてください',
            child: TextField(decoration: InputDecoration(hintText: '入力例')),
          ),
        ),
      ),
    );

    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((widget) => widget.properties.label == '叶えたい理由');
    expect(labels, hasLength(1));
    expect(labels.single.properties.header, isTrue);
    semantics.dispose();
  });
}

Widget _localizedApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

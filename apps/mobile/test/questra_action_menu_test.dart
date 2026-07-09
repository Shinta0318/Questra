import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/menu/questra_action_menu.dart';

enum _Action { edit, delete }

void main() {
  testWidgets('action button invokes its callback', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestraActionButton(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Quest詳細へ'),
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Quest詳細へ'));

    expect(pressed, isTrue);
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('popup menu renders icons and returns selected value', (
    tester,
  ) async {
    _Action? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestraPopupMenu<_Action>(
            tooltip: 'Trailメニュー',
            items: const [
              QuestraMenuItem(
                value: _Action.edit,
                label: '編集',
                icon: Icons.edit_outlined,
              ),
              QuestraMenuItem(
                value: _Action.delete,
                label: 'Trailを削除',
                icon: Icons.delete_outline,
                destructive: true,
              ),
            ],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    final trigger = find.byTooltip('Trailメニュー');
    expect(trigger, findsOneWidget);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    expect(find.text('編集'), findsOneWidget);
    expect(find.text('Trailを削除'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.text('Trailを削除'));
    await tester.pumpAndSettle();

    expect(selected, _Action.delete);
  });
}

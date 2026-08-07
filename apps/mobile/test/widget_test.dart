import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questra/main.dart';

void main() {
  testWidgets('Questra app starts on splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuestraApp()));

    expect(find.text('Questra'), findsWidgets);
    expect(find.text('挑戦が、\n君の星座になる。'), findsOneWidget);
    expect(find.text('Arcとの航海を始める'), findsOneWidget);
  });
}

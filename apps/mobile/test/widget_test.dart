import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questra/main.dart';

void main() {
  testWidgets('Questra app starts on splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuestraApp()));

    expect(find.text('Questra'), findsWidgets);
    expect(find.text('Adventure begins here.'), findsOneWidget);
    expect(find.text('Enter'), findsOneWidget);
  });
}

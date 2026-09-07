import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questra/main.dart';

void main() {
  testWidgets('Questra app starts on splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuestraApp()));

    expect(find.text('Questra'), findsWidgets);
    expect(find.text('やりたいことを、\n今日の一歩に。'), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('初めての方'), findsOneWidget);
  });
}

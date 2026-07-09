import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/motion/questra_motion.dart';
import 'package:questra/widgets/motion/questra_pressable.dart';

void main() {
  testWidgets('pressable scales down while pressed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestraPressable(child: SizedBox(width: 80, height: 48)),
        ),
      ),
    );

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(QuestraPressable)),
    );
    await tester.pump();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      QuestraMotion.pressedScale,
    );

    await gesture.up();
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('pressable respects disabled animations', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: QuestraPressable(child: SizedBox(width: 80, height: 48)),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(QuestraPressable)),
    );
    await tester.pump();

    final animatedScale = tester.widget<AnimatedScale>(
      find.byType(AnimatedScale),
    );
    expect(animatedScale.scale, 1);
    expect(animatedScale.duration, Duration.zero);

    await gesture.up();
  });
}

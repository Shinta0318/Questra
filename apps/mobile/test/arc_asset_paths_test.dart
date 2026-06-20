import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/performance_limits.dart';
import 'package:questra/widgets/arc/arc_asset_paths.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';
import 'package:questra/widgets/arc/arc_widget.dart';

void main() {
  test('maps Arc emotions to expression assets', () {
    expect(ArcAssetPaths.fromEmotion(ArcEmotion.normal), ArcAssetPaths.normal);
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.excited),
      ArcAssetPaths.excited,
    );
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.support),
      ArcAssetPaths.support,
    );
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.serious),
      ArcAssetPaths.serious,
    );
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.worried),
      ArcAssetPaths.worried,
    );
    expect(ArcAssetPaths.fromEmotion(ArcEmotion.lonely), ArcAssetPaths.lonely);
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.celebrate),
      ArcAssetPaths.celebrate,
    );
  });

  testWidgets('ArcWidget displays the normal expression asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArcWidget(emotion: ArcEmotion.normal, showSpeechBubble: false),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final assetImage = image.image as AssetImage;

    expect(assetImage.assetName, ArcAssetPaths.normal);
  });

  test('Arc expression PNG assets stay within the MVP size budget', () {
    const assetPaths = [
      ArcAssetPaths.normal,
      ArcAssetPaths.excited,
      ArcAssetPaths.support,
      ArcAssetPaths.serious,
      ArcAssetPaths.worried,
      ArcAssetPaths.lonely,
      ArcAssetPaths.celebrate,
    ];

    for (final assetPath in assetPaths) {
      final file = File(assetPath);

      expect(file.existsSync(), isTrue, reason: '$assetPath must exist');
      expect(
        file.lengthSync(),
        lessThanOrEqualTo(QuestraPerformanceLimits.arcAssetMaxBytes),
        reason: '$assetPath should stay under the Arc PNG size budget',
      );
    }
  });
}

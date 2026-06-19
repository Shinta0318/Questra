import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/arc/arc_asset_paths.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';
import 'package:questra/widgets/arc/arc_widget.dart';

void main() {
  test('maps Arc emotions to expression assets', () {
    expect(ArcAssetPaths.fromEmotion(ArcEmotion.normal), ArcAssetPaths.normal);
    expect(ArcAssetPaths.fromEmotion(ArcEmotion.excited), ArcAssetPaths.happy);
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.support),
      ArcAssetPaths.cheering,
    );
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.serious),
      ArcAssetPaths.serious,
    );
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.worried),
      ArcAssetPaths.worried,
    );
    expect(ArcAssetPaths.fromEmotion(ArcEmotion.lonely), ArcAssetPaths.sad);
    expect(
      ArcAssetPaths.fromEmotion(ArcEmotion.celebrate),
      ArcAssetPaths.celebration,
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
}

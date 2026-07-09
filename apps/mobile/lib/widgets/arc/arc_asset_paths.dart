import 'arc_emotion.dart';
import 'arc_visual_asset.dart';

class ArcAssetPaths {
  const ArcAssetPaths._();

  static const normal = 'assets/characters/arc/arc_normal.png';
  static const excited = 'assets/characters/arc/arc_excited.png';
  static const support = 'assets/characters/arc/arc_support.png';
  static const serious = 'assets/characters/arc/arc_serious.png';
  static const worried = 'assets/characters/arc/arc_worried.png';
  static const lonely = 'assets/characters/arc/arc_lonely.png';
  static const celebrate = 'assets/characters/arc/arc_celebrate.png';

  static String fromEmotion(ArcEmotion emotion) {
    return switch (emotion) {
      ArcEmotion.normal => normal,
      ArcEmotion.excited => excited,
      ArcEmotion.support => support,
      ArcEmotion.serious => serious,
      ArcEmotion.worried => worried,
      ArcEmotion.lonely => lonely,
      ArcEmotion.celebrate => celebrate,
    };
  }

  static ArcVisualAsset assetForEmotion(ArcEmotion emotion) {
    return ArcVisualAsset(
      type: ArcVisualAssetType.png,
      path: fromEmotion(emotion),
      semanticLabel: 'Arc ${emotion.label} PNG expression',
    );
  }
}

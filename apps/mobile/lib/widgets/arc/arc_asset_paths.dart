import 'arc_emotion.dart';

class ArcAssetPaths {
  const ArcAssetPaths._();

  static const normal = 'assets/characters/arc/arc_normal.png';
  static const happy = 'assets/characters/arc/arc_happy.png';
  static const cheering = 'assets/characters/arc/arc_cheering.png';
  static const serious = 'assets/characters/arc/arc_serious.png';
  static const worried = 'assets/characters/arc/arc_worried.png';
  static const sad = 'assets/characters/arc/arc_sad.png';
  static const celebration = 'assets/characters/arc/arc_celebration.png';

  static String fromEmotion(ArcEmotion emotion) {
    return switch (emotion) {
      ArcEmotion.normal => normal,
      ArcEmotion.excited => happy,
      ArcEmotion.support => cheering,
      ArcEmotion.serious => serious,
      ArcEmotion.worried => worried,
      ArcEmotion.lonely => sad,
      ArcEmotion.celebrate => celebration,
    };
  }
}

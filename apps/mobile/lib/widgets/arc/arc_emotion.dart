enum ArcEmotion {
  normal,
  excited,
  support,
  serious,
  worried,
  lonely,
  celebrate,
}

extension ArcEmotionLabel on ArcEmotion {
  String get label {
    return switch (this) {
      ArcEmotion.normal => 'Normal',
      ArcEmotion.excited => 'Excited',
      ArcEmotion.support => 'Support',
      ArcEmotion.serious => 'Serious',
      ArcEmotion.worried => 'Worried',
      ArcEmotion.lonely => 'Lonely',
      ArcEmotion.celebrate => 'Celebrate',
    };
  }
}

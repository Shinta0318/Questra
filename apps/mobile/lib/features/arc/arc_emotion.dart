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

  String get face {
    return switch (this) {
      ArcEmotion.normal => '•‿•',
      ArcEmotion.excited => '✦‿✦',
      ArcEmotion.support => 'ᵕ‿ᵕ',
      ArcEmotion.serious => '•_•',
      ArcEmotion.worried => '•︵•',
      ArcEmotion.lonely => '._.',
      ArcEmotion.celebrate => '★‿★',
    };
  }
}

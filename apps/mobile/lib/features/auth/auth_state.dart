enum QuestInterest { adventure, learning, health, work, family, challenge }

enum SignalFrequency { quiet, balanced, frequent }

extension QuestInterestLabel on QuestInterest {
  String get label {
    return switch (this) {
      QuestInterest.adventure => '冒険',
      QuestInterest.learning => '学習',
      QuestInterest.health => '健康',
      QuestInterest.work => '仕事',
      QuestInterest.family => '家族',
      QuestInterest.challenge => '挑戦',
    };
  }

  String get storageKey => name;
}

extension SignalFrequencyLabel on SignalFrequency {
  String get label {
    return switch (this) {
      SignalFrequency.quiet => '静かめ',
      SignalFrequency.balanced => 'ふつう',
      SignalFrequency.frequent => 'こまめ',
    };
  }

  String get storageKey => name;
}

QuestInterest questInterestFromStorage(String? value) {
  return QuestInterest.values.firstWhere(
    (interest) => interest.storageKey == value,
    orElse: () => QuestInterest.adventure,
  );
}

SignalFrequency signalFrequencyFromStorage(String? value) {
  return SignalFrequency.values.firstWhere(
    (frequency) => frequency.storageKey == value,
    orElse: () => SignalFrequency.balanced,
  );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    this.loginId,
    this.arcName = 'Arc',
    this.questInterest = QuestInterest.adventure,
    this.signalFrequency = SignalFrequency.balanced,
    this.onboardingCompleted = false,
    this.hasSeenOnboardingTour = false,
    this.arcLevel = 1,
    this.bondScore = 0,
    this.stardustBalance = 0,
    this.navigatorRank = 'novice',
  });

  final String id;
  final String email;
  final String nickname;
  final String? loginId;
  final String arcName;
  final QuestInterest questInterest;
  final SignalFrequency signalFrequency;
  final bool onboardingCompleted;
  final bool hasSeenOnboardingTour;
  final int arcLevel;
  final int bondScore;
  final int stardustBalance;
  final String navigatorRank;

  UserProfile copyWith({
    String? id,
    String? email,
    String? nickname,
    String? loginId,
    String? arcName,
    QuestInterest? questInterest,
    SignalFrequency? signalFrequency,
    bool? onboardingCompleted,
    bool? hasSeenOnboardingTour,
    int? arcLevel,
    int? bondScore,
    int? stardustBalance,
    String? navigatorRank,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      loginId: loginId ?? this.loginId,
      arcName: arcName ?? this.arcName,
      questInterest: questInterest ?? this.questInterest,
      signalFrequency: signalFrequency ?? this.signalFrequency,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      hasSeenOnboardingTour:
          hasSeenOnboardingTour ?? this.hasSeenOnboardingTour,
      arcLevel: arcLevel ?? this.arcLevel,
      bondScore: bondScore ?? this.bondScore,
      stardustBalance: stardustBalance ?? this.stardustBalance,
      navigatorRank: navigatorRank ?? this.navigatorRank,
    );
  }
}

class AuthState {
  const AuthState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.registrationCompleted = false,
    this.passwordResetRequested = false,
    this.passwordResetCompleted = false,
    this.isPasswordRecovery = false,
  });

  final UserProfile? profile;
  final bool isLoading;
  final String? errorMessage;
  final bool registrationCompleted;
  final bool passwordResetRequested;
  final bool passwordResetCompleted;
  final bool isPasswordRecovery;

  bool get isAuthenticated => profile != null;

  AuthState copyWith({
    UserProfile? profile,
    bool? clearProfile,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? registrationCompleted,
    bool? passwordResetRequested,
    bool? passwordResetCompleted,
    bool? isPasswordRecovery,
  }) {
    return AuthState(
      profile: clearProfile == true ? null : profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      registrationCompleted:
          registrationCompleted ?? this.registrationCompleted,
      passwordResetRequested:
          passwordResetRequested ?? this.passwordResetRequested,
      passwordResetCompleted:
          passwordResetCompleted ?? this.passwordResetCompleted,
      isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
    );
  }
}

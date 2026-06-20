class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    this.onboardingCompleted = false,
    this.arcLevel = 1,
    this.bondScore = 0,
    this.stardustBalance = 0,
    this.navigatorRank = 'novice',
  });

  final String id;
  final String email;
  final String nickname;
  final bool onboardingCompleted;
  final int arcLevel;
  final int bondScore;
  final int stardustBalance;
  final String navigatorRank;

  UserProfile copyWith({
    String? id,
    String? email,
    String? nickname,
    bool? onboardingCompleted,
    int? arcLevel,
    int? bondScore,
    int? stardustBalance,
    String? navigatorRank,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      arcLevel: arcLevel ?? this.arcLevel,
      bondScore: bondScore ?? this.bondScore,
      stardustBalance: stardustBalance ?? this.stardustBalance,
      navigatorRank: navigatorRank ?? this.navigatorRank,
    );
  }
}

class AuthState {
  const AuthState({this.profile, this.isLoading = false, this.errorMessage});

  final UserProfile? profile;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => profile != null;

  AuthState copyWith({
    UserProfile? profile,
    bool? clearProfile,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      profile: clearProfile == true ? null : profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_state.dart';

void main() {
  test('profile stores onboarding personalization preferences', () {
    const profile = UserProfile(
      id: 'user-1',
      email: 'captain@example.com',
      nickname: '旅人',
    );

    final updated = profile.copyWith(
      nickname: 'Shinta',
      arcName: 'アーク',
      questInterest: QuestInterest.learning,
      signalFrequency: SignalFrequency.quiet,
      onboardingCompleted: true,
    );

    expect(updated.nickname, 'Shinta');
    expect(updated.arcName, 'アーク');
    expect(updated.questInterest.label, '学習');
    expect(updated.signalFrequency.label, '静かめ');
    expect(updated.onboardingCompleted, isTrue);
  });

  test('storage mapping falls back to beta-safe defaults', () {
    expect(questInterestFromStorage('health'), QuestInterest.health);
    expect(questInterestFromStorage('unknown'), QuestInterest.adventure);
    expect(signalFrequencyFromStorage('frequent'), SignalFrequency.frequent);
    expect(signalFrequencyFromStorage(null), SignalFrequency.balanced);
  });
}

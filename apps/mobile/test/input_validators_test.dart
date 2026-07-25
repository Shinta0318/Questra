import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/validation/input_validators.dart';

void main() {
  group('InputValidators.email', () {
    test('accepts practical email formats', () {
      expect(InputValidators.email('captain+beta@questra.app'), isNull);
      expect(InputValidators.email('旅人@例.jp'), isNull);
    });

    test('rejects missing domain and repeated dots', () {
      expect(InputValidators.email('captain@questra'), isNotNull);
      expect(InputValidators.email('captain..beta@questra.app'), isNotNull);
      expect(InputValidators.email('captain@quest..app'), isNotNull);
    });
  });

  group('InputValidators.phone', () {
    test('accepts domestic and international formatting', () {
      expect(InputValidators.phone('090-1234-5678'), isNull);
      expect(InputValidators.phone('+81 90 1234 5678'), isNull);
    });

    test('rejects letters and invalid digit counts', () {
      expect(InputValidators.phone('03-ABCD-5678'), isNotNull);
      expect(InputValidators.phone('12345'), isNotNull);
    });

    test('allows an empty optional phone number', () {
      expect(InputValidators.phone(''), isNull);
      expect(InputValidators.phone('', required: true), isNotNull);
    });
  });

  group('InputValidators.loginId', () {
    test('accepts normalized login IDs', () {
      expect(InputValidators.loginId('captain_2026'), isNull);
      expect(InputValidators.loginIdentifier('captain-2026'), isNull);
      expect(
        InputValidators.loginIdentifier('captain@questra.app'),
        isNull,
      );
    });

    test('rejects spaces, symbols, and short values', () {
      expect(InputValidators.loginId('ab'), isNotNull);
      expect(InputValidators.loginId('Captain Star'), isNotNull);
      expect(InputValidators.loginId('_captain'), isNotNull);
    });
  });

  test('new password requires length, letters, and numbers', () {
    expect(InputValidators.newPassword('short1'), isNotNull);
    expect(InputValidators.newPassword('onlyletters'), isNotNull);
    expect(InputValidators.newPassword('voyage2026'), isNull);
  });

  test('password confirmation must match', () {
    expect(
      InputValidators.passwordConfirmation('voyage2026', 'voyage2026'),
      isNull,
    );
    expect(
      InputValidators.passwordConfirmation('different', 'voyage2026'),
      isNotNull,
    );
  });

  test('Arc chat rejects blank and over-limit messages', () {
    expect(InputValidators.arcChat('   '), isNotNull);
    expect(
      InputValidators.arcChat('a' * (InputLimits.arcChatMessage + 1)),
      isNotNull,
    );
    expect(InputValidators.arcChat('次のMissionを一緒に考えたい。'), isNull);
  });
}

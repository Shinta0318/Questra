abstract final class InputLimits {
  static const email = 254;
  static const loginId = 40;
  static const phone = 32;
  static const password = 72;
  static const nickname = 30;
  static const arcName = 30;
  static const questTitle = 100;
  static const questDescription = 1000;
  static const category = 40;
  static const missionTitle = 100;
  static const missionDescription = 600;
  static const trailTitle = 100;
  static const trailSummary = 280;
  static const trailContent = 3000;
  static const reflection = 1200;
  static const feedbackSummary = 160;
  static const feedbackDetail = 2000;
  static const arcChatMessage = 1200;
  static const arcQuestIdea = 1000;
}

abstract final class InputValidators {
  static String? requiredText(
    String? value, {
    required String fieldName,
    required int maxLength,
    int minLength = 1,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$fieldNameを入力してください。';
    if (text.length < minLength) {
      return '$fieldNameは$minLength文字以上で入力してください。';
    }
    if (text.length > maxLength) {
      return '$fieldNameは$maxLength文字以内で入力してください。';
    }
    if (_containsUnsupportedControlCharacter(text)) {
      return '$fieldNameに使用できない文字が含まれています。';
    }
    return null;
  }

  static String? optionalText(
    String? value, {
    required String fieldName,
    required int maxLength,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return requiredText(
      text,
      fieldName: fieldName,
      maxLength: maxLength,
    );
  }

  static String? email(String? value, {bool required = true}) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return required ? 'メールアドレスを入力してください。' : null;
    if (email.length > InputLimits.email || email.contains(RegExp(r'\s'))) {
      return 'メールアドレスの形式を確認してください。';
    }

    final at = email.lastIndexOf('@');
    if (at <= 0 || at != email.indexOf('@') || at == email.length - 1) {
      return 'メールアドレスの形式を確認してください。';
    }
    final local = email.substring(0, at);
    final domain = email.substring(at + 1);
    if (local.length > 64 ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..') ||
        domain.startsWith('.') ||
        domain.endsWith('.') ||
        domain.contains('..')) {
      return 'メールアドレスの形式を確認してください。';
    }
    final labels = domain.split('.');
    if (labels.length < 2 ||
        labels.any(
          (label) =>
              label.isEmpty ||
              label.length > 63 ||
              label.startsWith('-') ||
              label.endsWith('-'),
        )) {
      return 'メールアドレスの形式を確認してください。';
    }
    return null;
  }

  static String? loginId(String? value) {
    final loginId = value?.trim().toLowerCase() ?? '';
    if (loginId.isEmpty) return 'ログインIDを入力してください。';
    if (loginId.length < 3 || loginId.length > InputLimits.loginId) {
      return 'ログインIDは3〜${InputLimits.loginId}文字で入力してください。';
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(loginId)) {
      return 'ログインIDは半角英数字で始め、英数字・ピリオド・ハイフン・アンダーバーを使用してください。';
    }
    return null;
  }

  static String? loginIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) return 'ログインIDまたはメールアドレスを入力してください。';
    return identifier.contains('@') ? email(identifier) : loginId(identifier);
  }

  static String? phone(String? value, {bool required = false}) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return required ? '電話番号を入力してください。' : null;
    if (phone.length > InputLimits.phone) return '電話番号の形式を確認してください。';

    final normalized = phone.replaceAll(RegExp(r'[\s\-‐‑–—().]'), '');
    if (!RegExp(r'^\+?\d+$').hasMatch(normalized) ||
        normalized.indexOf('+') > 0) {
      return '電話番号の形式を確認してください。';
    }
    final digits = normalized.replaceFirst('+', '');
    if (digits.length < 7 || digits.length > 15) {
      return '電話番号は国番号を含め7〜15桁で入力してください。';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'パスワードを入力してください。';
    if (password.length > InputLimits.password) {
      return 'パスワードは${InputLimits.password}文字以内で入力してください。';
    }
    return null;
  }

  static String? newPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'パスワードを入力してください。';
    if (password.length < 8) return 'パスワードは8文字以上で入力してください。';
    if (password.length > InputLimits.password) {
      return 'パスワードは${InputLimits.password}文字以内で入力してください。';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'パスワードには英字と数字を含めてください。';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if ((value ?? '').isEmpty) return '確認用パスワードを入力してください。';
    if (value != password) return 'パスワードが一致しません。';
    return null;
  }

  static String? arcChat(String? value) => requiredText(
        value,
        fieldName: 'メッセージ',
        maxLength: InputLimits.arcChatMessage,
      );

  static bool _containsUnsupportedControlCharacter(String value) {
    return value.codeUnits.any(
      (unit) => unit < 32 && unit != 9 && unit != 10 && unit != 13,
    );
  }
}

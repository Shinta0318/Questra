import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, FunctionException;

import 'auth_state.dart';

AuthException loginFunctionFailure(FunctionException error) {
  final details = error.details;
  final code = details is Map ? details['code'] : null;
  if (error.status == 429 || code == 'rate_limited') {
    return const AuthException('rate_limited', code: 'over_request_rate_limit');
  }
  if (error.status == 401 && code == 'invalid_credentials') {
    return const AuthException(
      'invalid_credentials',
      code: 'invalid_credentials',
    );
  }
  return const AuthException('login_unavailable', code: 'login_unavailable');
}

String friendlyAuthError(AuthException error, AuthErrorContext? context) {
  final code = error.code;
  final message = error.message.toLowerCase();
  if (code == 'local_mock_account_missing') {
    return 'このプレビューには登録済みアカウントがありません。画面を見るには「モックを開く」を選んでください。';
  }
  if (code == 'local_mock_invalid_credentials') {
    return 'プレビュー用のログインIDまたはパスワードが違います。';
  }
  if (code == 'local_mail_unavailable') {
    return 'このオフラインモックでは認証メールを送信・確認できません。';
  }
  if (code == 'password_reset_sign_out_failed') {
    return 'パスワードは更新されましたが、セッションを終了できませんでした。通信状態を確認して、もう一度お試しください。';
  }
  if (code == 'login_unavailable') {
    return 'ログインサービスに接続できませんでした。通信状態を確認し、少し待ってからお試しください。';
  }
  if (code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit' ||
      message.contains('rate') ||
      message.contains('too many') ||
      message.contains('60 seconds')) {
    return '操作が続いたため一時停止しています。少し待ってからお試しください。';
  }
  if (context == AuthErrorContext.confirmation) {
    return '確認メールの再送を受け付けられませんでした。時間をおいて、もう一度お試しください。';
  }
  if (context == AuthErrorContext.legalConsent) {
    return '利用条件への同意を保存できませんでした。しばらくしてから再試行してください。';
  }
  if (context == AuthErrorContext.signup) {
    if (code == 'app_update_required') {
      return '利用条件が更新されました。Questraを更新してから、もう一度お試しください。';
    }
    if (code == 'signup_unavailable') {
      return '現在、新規登録の準備が整っていません。入力内容はそのままに、時間をおいてお試しください。';
    }
    if (code == 'email_address_invalid') {
      return 'このメールアドレスは登録に使用できません。受信できるメールアドレスを入力してください。';
    }
    if (code == 'email_exists' || code == 'user_already_exists') {
      return 'メールアドレスまたはログインIDが登録済みの可能性があります。入力内容を確認してください。';
    }
    if (code == 'weak_password' || message.contains('weak password')) {
      return 'パスワードは8文字以上で、英字と数字を含めてください。';
    }
    if (code == 'unexpected_failure' || message.contains('database error')) {
      return '登録処理で問題が起きました。ログインIDの重複などの可能性があります。別のIDでも続く場合は時間をおいてください。';
    }
    if (code == 'validation_failed') {
      return '入力内容を確認してください。ログインIDは半角英数字・._- を使って3〜40文字です。';
    }
    if (message.contains('legal_acceptance')) {
      return '年齢条件、利用規約、プライバシー説明、AI処理の内容を確認してください。';
    }
    return 'アカウントを作成できませんでした。入力内容を確認して、もう一度お試しください。';
  }
  if (context == AuthErrorContext.login) {
    return 'ログインIDまたはパスワードを確認してください。10回連続で失敗すると30分間ログインできません。';
  }
  if (message.contains('session') || message.contains('recovery')) {
    return '再設定リンクが無効または期限切れです。もう一度メールを送信してください。';
  }
  return '認証処理を完了できませんでした。通信状態を確認して、もう一度お試しください。';
}

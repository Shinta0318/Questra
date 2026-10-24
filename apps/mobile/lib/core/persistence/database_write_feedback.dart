import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class DatabaseWriteFeedback {
  const DatabaseWriteFeedback(this.message);

  final String message;

  static DatabaseWriteFeedback? from(Object error) {
    if (error is! PostgrestException) return null;
    return switch (error.code) {
      '23505' => const DatabaseWriteFeedback(
        'すでに登録されているデータと重複しています。最新の内容を確認してください。',
      ),
      '23503' => const DatabaseWriteFeedback(
        '関連するデータが見つかりません。画面を再読み込みして選び直してください。',
      ),
      '23502' => const DatabaseWriteFeedback('必須情報が不足しています。入力内容を確認してください。'),
      '23514' || '22001' || '22P02' => const DatabaseWriteFeedback(
        '入力内容が登録条件に合いません。文字数や日付などを確認してください。',
      ),
      '42501' => const DatabaseWriteFeedback('保存する権限がありません。ログイン状態を確認してください。'),
      _ => null,
    };
  }
}

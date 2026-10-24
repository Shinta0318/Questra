import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

String? aiLegalFailureReason(Object error) {
  if (error is! FunctionException || error.details is! Map) return null;
  final code = (error.details as Map)['error'];
  if (error.status == 403 && code == 'consent_required') {
    return 'consent_required';
  }
  if (error.status == 503 && code == 'consent_check_unavailable') {
    return 'consent_check_unavailable';
  }
  return null;
}

String? aiLegalFailureMessage(Object error) =>
    switch (aiLegalFailureReason(error)) {
      'consent_required' => '登録時の利用条件の記録が見つかりません。確認できるまで、内容はAIへ送っていません。',
      'consent_check_unavailable' =>
        '利用条件の記録を確認できないため、内容はAIへ送っていません。入力は残っています。少し待ってから再試行してください。',
      _ => null,
    };

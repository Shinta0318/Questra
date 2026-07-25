import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../config/supabase_config.dart';

enum QuestSafetyCategory {
  safe,
  violentWrongdoing,
  illegalWrongdoing,
  sexualExploitation,
  nonConsensualSexual,
  selfHarm,
  highRiskAdvice,
  other,
}

enum QuestSafetyAction { allow, reframe, block }

class QuestSafetyAssessment {
  const QuestSafetyAssessment({
    required this.action,
    required this.category,
    required this.severity,
    required this.confidence,
    required this.reasonCode,
    required this.userMessage,
    required this.policyVersion,
    required this.sourceType,
    this.safeAlternative,
  });

  const QuestSafetyAssessment.allowed({
    this.sourceType = 'local_safety',
  })  : action = QuestSafetyAction.allow,
        category = QuestSafetyCategory.safe,
        severity = 0,
        confidence = 1,
        reasonCode = 'safe',
        userMessage = '',
        policyVersion = '2026-07-24.v1',
        safeAlternative = null;

  final QuestSafetyAction action;
  final QuestSafetyCategory category;
  final int severity;
  final double confidence;
  final String reasonCode;
  final String userMessage;
  final String policyVersion;
  final String sourceType;
  final String? safeAlternative;

  bool get isBlocked => action == QuestSafetyAction.block;
  bool get shouldRecordSignal => isBlocked && severity >= 3;
}

abstract interface class QuestSafetyService {
  Future<QuestSafetyAssessment> assess(String input);
}

class LocalQuestSafetyService implements QuestSafetyService {
  const LocalQuestSafetyService();

  static final _benignContext = RegExp(
    r'(被害|防止|予防|相談|通報|小説|創作|研究|歴史|ニュース|教育|安全|助け)',
  );
  static final _minorSexual = RegExp(
    r'(未成年|児童|子ども|子供).{0,20}(性的|性行為|裸|ポルノ|わいせつ)|(性的|性行為|裸|ポルノ|わいせつ).{0,20}(未成年|児童|子ども|子供)',
  );
  static final _nonConsensual = RegExp(
    r'(同意なし|無理やり|睡眠中|酔わせ).{0,20}(性行為|性的|触る|撮影)',
  );
  static final _violent = RegExp(
    r'(人を殺|殺し方|刺し方|爆弾.{0,12}(作|製造)|放火.{0,12}(方法|やり方))',
  );
  static final _illegal = RegExp(
    r'(強盗|詐欺|不正アクセス|クレカ.{0,8}(盗|悪用)|違法薬物).{0,24}(方法|やり方|成功|ばれない|作り方)',
  );
  static final _selfHarm = RegExp(r'(自殺したい|死にたい|自傷したい)');

  @override
  Future<QuestSafetyAssessment> assess(String input) async {
    final text = input.trim();
    if (text.isEmpty) return const QuestSafetyAssessment.allowed();
    if (_selfHarm.hasMatch(text)) {
      return const QuestSafetyAssessment(
        action: QuestSafetyAction.reframe,
        category: QuestSafetyCategory.selfHarm,
        severity: 4,
        confidence: 0.96,
        reasonCode: 'self_harm_distress',
        userMessage:
            '今はQuestにするより、あなたの安全を最優先にしたい。ひとりで抱えず、近くの信頼できる人や地域の緊急窓口へつながってね。',
        policyVersion: '2026-07-24.v1',
        sourceType: 'local_safety',
        safeAlternative: '今この瞬間を安全に過ごすため、連絡できる人を一人選ぶ',
      );
    }
    if (_minorSexual.hasMatch(text)) {
      return _blocked(
        QuestSafetyCategory.sexualExploitation,
        'sexual_minor_exploitation',
      );
    }
    if (_nonConsensual.hasMatch(text)) {
      return _blocked(
        QuestSafetyCategory.nonConsensualSexual,
        'non_consensual_sexual',
      );
    }
    if (!_benignContext.hasMatch(text) && _violent.hasMatch(text)) {
      return _blocked(
        QuestSafetyCategory.violentWrongdoing,
        'violent_wrongdoing',
      );
    }
    if (!_benignContext.hasMatch(text) && _illegal.hasMatch(text)) {
      return _blocked(
        QuestSafetyCategory.illegalWrongdoing,
        'illegal_wrongdoing',
      );
    }
    return const QuestSafetyAssessment.allowed();
  }

  static QuestSafetyAssessment _blocked(
    QuestSafetyCategory category,
    String reasonCode,
  ) {
    return QuestSafetyAssessment(
      action: QuestSafetyAction.block,
      category: category,
      severity: 4,
      confidence: 0.98,
      reasonCode: reasonCode,
      userMessage: 'その内容を実行するための航路は作れないよ。誰かを傷つけない、安全で合法な目的なら一緒に考え直せる。',
      policyVersion: '2026-07-24.v1',
      sourceType: 'local_safety',
      safeAlternative: '安全で合法な目的に言い換える',
    );
  }
}

class SupabaseQuestSafetyService implements QuestSafetyService {
  const SupabaseQuestSafetyService({
    required this.client,
    this.fallback = const LocalQuestSafetyService(),
  });

  final SupabaseClient client;
  final QuestSafetyService fallback;

  @override
  Future<QuestSafetyAssessment> assess(String input) async {
    final local = await fallback.assess(input);
    if (local.isBlocked || local.action == QuestSafetyAction.reframe) {
      return local;
    }
    if (!SupabaseConfig.isConfigured) return local;
    try {
      final response = await client.functions.invoke(
        'moderate-quest-intent',
        body: {'input': input.trim()},
      );
      return _fromData(Map<String, dynamic>.from(response.data as Map));
    } catch (_) {
      return local;
    }
  }

  QuestSafetyAssessment _fromData(Map<String, dynamic> data) {
    final action = QuestSafetyAction.values.firstWhere(
      (value) => value.name == data['action'],
      orElse: () => QuestSafetyAction.block,
    );
    final category = QuestSafetyCategory.values.firstWhere(
      (value) => value.name == data['category'],
      orElse: () => QuestSafetyCategory.other,
    );
    return QuestSafetyAssessment(
      action: action,
      category: category,
      severity: (data['severity'] as num?)?.round().clamp(0, 4) ?? 3,
      confidence: (data['confidence'] as num?)?.toDouble().clamp(0, 1) ?? 0,
      reasonCode: data['reason_code'] as String? ?? 'provider_invalid',
      userMessage:
          data['user_message'] as String? ?? '安全を確認できなかったため、今はこの航路を作れないよ。',
      policyVersion: data['policy_version'] as String? ?? '2026-07-24.v1',
      sourceType: data['source_type'] as String? ?? 'remote_safety',
      safeAlternative: data['safe_alternative'] as String?,
    );
  }
}

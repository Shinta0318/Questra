class LegalAcceptance {
  LegalAcceptance({
    required this.eligibilityVersion,
    required this.termsVersion,
    required this.privacyVersion,
    required this.aiDisclosureVersion,
    required this.regionCode,
    required this.minimumAgeConfirmed,
    required this.acceptedAt,
  });

  final String eligibilityVersion;
  final String termsVersion;
  final String privacyVersion;
  final String aiDisclosureVersion;
  final String regionCode;
  final bool minimumAgeConfirmed;
  final DateTime acceptedAt;

  bool get isCurrent =>
      eligibilityVersion == QuestraLegalPolicy.eligibilityVersion &&
      termsVersion == QuestraLegalPolicy.termsVersion &&
      privacyVersion == QuestraLegalPolicy.privacyVersion &&
      aiDisclosureVersion == QuestraLegalPolicy.aiDisclosureVersion &&
      regionCode == QuestraLegalPolicy.regionCode &&
      minimumAgeConfirmed;

  Map<String, Object> toAuthMetadata() => {
    'eligibility_version': eligibilityVersion,
    'terms_version': termsVersion,
    'privacy_version': privacyVersion,
    'ai_disclosure_version': aiDisclosureVersion,
    'region_code': regionCode,
    'minimum_age_confirmed': minimumAgeConfirmed,
    'legal_accepted_at': acceptedAt.toUtc().toIso8601String(),
  };
}

enum ActiveLegalPolicyState { current, unavailable, updateRequired }

abstract final class QuestraLegalPolicy {
  static const minimumAge = 18;
  static const regionCode = 'JP';
  static const regionLabel = '日本向け内部Beta';
  static const eligibilityVersion = '2026-08-18-beta.1';
  static const termsVersion = '2026-08-18-beta.1';
  static const privacyVersion = '2026-08-18-beta.1';
  static const aiDisclosureVersion = '2026-08-18-beta.1';

  static bool matchesSignupMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return false;
    final acceptedAt = metadata['legal_accepted_at'];
    return metadata['eligibility_version'] == eligibilityVersion &&
        metadata['terms_version'] == termsVersion &&
        metadata['privacy_version'] == privacyVersion &&
        metadata['ai_disclosure_version'] == aiDisclosureVersion &&
        metadata['region_code'] == regionCode &&
        metadata['minimum_age_confirmed'] == true &&
        acceptedAt is String &&
        DateTime.tryParse(acceptedAt) != null;
  }

  static bool matchesActiveReleasePolicy(Map<String, dynamic>? policy) =>
      policy != null &&
      policy['active'] == true &&
      policy['minimum_age'] == minimumAge &&
      policy['eligibility_version'] == eligibilityVersion &&
      policy['terms_version'] == termsVersion &&
      policy['privacy_version'] == privacyVersion &&
      policy['ai_disclosure_version'] == aiDisclosureVersion;

  static ActiveLegalPolicyState activePolicyState(
    Map<String, dynamic>? policy,
  ) {
    if (policy == null) return ActiveLegalPolicyState.unavailable;
    return matchesActiveReleasePolicy(policy)
        ? ActiveLegalPolicyState.current
        : ActiveLegalPolicyState.updateRequired;
  }

  static LegalAcceptance acceptance({DateTime? acceptedAt}) => LegalAcceptance(
    eligibilityVersion: eligibilityVersion,
    termsVersion: termsVersion,
    privacyVersion: privacyVersion,
    aiDisclosureVersion: aiDisclosureVersion,
    regionCode: regionCode,
    minimumAgeConfirmed: true,
    acceptedAt: acceptedAt ?? DateTime.now(),
  );
}

class MissionReference {
  const MissionReference({
    required this.title,
    required this.publisher,
    required this.url,
    required this.retrievedAt,
    this.verified = true,
  });

  final String title;
  final String publisher;
  final Uri url;
  final DateTime retrievedAt;
  final bool verified;
}

class MissionResearchResult {
  const MissionResearchResult({
    required this.summary,
    required this.checkpoints,
    required this.cautions,
    required this.references,
    required this.sourceType,
  });

  final String summary;
  final List<String> checkpoints;
  final List<String> cautions;
  final List<MissionReference> references;
  final String sourceType;
}

enum EnterpriseSupportRole { sponsor, coach, partner, officialEventHost }

class EnterpriseSupportProposal {
  const EnterpriseSupportProposal({
    required this.enterpriseName,
    required this.role,
    required this.title,
    required this.description,
    required this.benefit,
    required this.userCost,
    required this.eligibility,
    required this.validUntil,
    required this.destination,
    required this.disclosure,
    required this.selectionReason,
    required this.reviewed,
  });

  final String enterpriseName;
  final EnterpriseSupportRole role;
  final String title;
  final String description;
  final String benefit;
  final String userCost;
  final String eligibility;
  final DateTime validUntil;
  final Uri destination;
  final String disclosure;
  final String selectionReason;
  final bool reviewed;

  bool get canDisplay =>
      reviewed &&
      destination.scheme == 'https' &&
      validUntil.isAfter(DateTime.now());
}

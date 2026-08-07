class MissionSourceReference {
  const MissionSourceReference({
    required this.title,
    required this.url,
    required this.publisher,
    required this.checkedAt,
    this.recheckAfter,
    this.isOfficial = false,
  });

  final String title;
  final Uri url;
  final String publisher;
  final DateTime checkedAt;
  final DateTime? recheckAfter;
  final bool isOfficial;

  bool isFreshAt(DateTime now) =>
      recheckAfter == null || now.isBefore(recheckAfter!);
}

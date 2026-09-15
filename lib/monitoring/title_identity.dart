class TitleIdentity {
  const TitleIdentity({
    required this.title,
    required this.contentType,
    required this.releaseYear,
    this.imdbId,
    this.tmdbId,
    this.availabilityProviderId,
  });

  final String title;
  final String contentType;
  final int releaseYear;
  final String? imdbId;
  final String? tmdbId;
  final String? availabilityProviderId;

  bool get isTvSeries => contentType.trim().toLowerCase() == 'tv series';

  String get normalizedTitle => normalizeTitleName(title);

  bool get hasExternalId =>
      (imdbId != null && imdbId!.trim().isNotEmpty) ||
      (tmdbId != null && tmdbId!.trim().isNotEmpty) ||
      (availabilityProviderId != null &&
          availabilityProviderId!.trim().isNotEmpty);
}

String normalizeTitleName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s+]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Title identity used for availability matching.
///
/// A platform may go LIVE only after a verified identity match AND verified
/// platform evidence. A title name by itself is never enough.
class TitleIdentity {
  const TitleIdentity({
    required this.title,
    required this.contentType,
    required this.releaseYear,
    this.alternateTitle,
    this.director,
    this.producer,
    this.writer,
    this.imdbId,
    this.tmdbId,
    this.availabilityProviderId,
  });

  final String title;
  final String? alternateTitle;
  final String contentType;
  final int releaseYear;
  final String? director;
  final String? producer;
  final String? writer;
  final String? imdbId;
  final String? tmdbId;
  final String? availabilityProviderId;

  bool get isTvSeries => contentType.trim().toLowerCase() == 'tv series';

  String get normalizedTitle => normalizeTitleName(title);

  String? get normalizedAlternateTitle {
    final value = alternateTitle?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return normalizeTitleName(value);
  }

  bool get hasTmdbId => tmdbId != null && tmdbId!.trim().isNotEmpty;

  bool get hasImdbId => imdbId != null && imdbId!.trim().isNotEmpty;

  bool get hasExternalId =>
      hasImdbId ||
      hasTmdbId ||
      (availabilityProviderId != null &&
          availabilityProviderId!.trim().isNotEmpty);

  bool get hasCredits =>
      _hasValue(director) || _hasValue(producer) || _hasValue(writer);
}

bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

String normalizeTitleName(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s+]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeCreditName(String value) {
  return normalizeTitleName(value);
}

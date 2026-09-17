/// Provider-neutral title search so the user can pick the exact production.
///
/// TMDb is the first implementation. A name search never marks a platform LIVE.
class TitleLookupMatch {
  const TitleLookupMatch({
    required this.name,
    required this.contentType,
    this.year,
    this.tmdbId,
    this.posterUrl,
  });

  final String name;
  final String contentType;
  final int? year;
  final String? tmdbId;
  final String? posterUrl;

  String get id => '${contentType.toLowerCase()}:${tmdbId ?? name}:$year';

  String get label {
    final yearLabel = year == null ? 'Year unknown' : '$year';
    return '$name  ·  $contentType  ·  $yearLabel';
  }

  @override
  bool operator ==(Object other) {
    return other is TitleLookupMatch && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// A TMDb numeric id, optionally with tv/movie from a pasted URL.
class TmdbTitleReference {
  const TmdbTitleReference({required this.id, this.mediaType});

  final String id;
  final String? mediaType;

  List<String> get mediaTypes =>
      mediaType == null ? const ['tv', 'movie'] : [mediaType!];
}

/// Accepts a TMDb page URL or a numeric id so obscure titles can still be found.
TmdbTitleReference? parseTmdbTitleReference(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (RegExp(r'^\d+$').hasMatch(trimmed)) {
    return TmdbTitleReference(id: trimmed);
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  if (!uri.host.toLowerCase().contains('themoviedb.org')) {
    return null;
  }
  final segments = uri.pathSegments;
  for (var i = 0; i < segments.length; i++) {
    final part = segments[i].toLowerCase();
    if (part != 'tv' && part != 'movie') {
      continue;
    }
    if (i + 1 >= segments.length) {
      continue;
    }
    final id = segments[i + 1].split('-').first;
    if (RegExp(r'^\d+$').hasMatch(id)) {
      return TmdbTitleReference(id: id, mediaType: part);
    }
  }
  return null;
}

abstract class TitleLookup {
  bool get isConfigured;

  Future<List<TitleLookupMatch>> searchByName({
    required String name,
    String? contentType,
    int? year,
  });
}

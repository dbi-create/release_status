import 'package:release_status/models/match_confidence.dart';
import 'package:release_status/monitoring/title_identity.dart';

/// Classifies TMDb (or other) search candidates.
///
/// Verified match requires content type plus either:
/// - a matching external id, or
/// - an exact/normalized title AND matching release year.
///
/// Credits can disambiguate or downgrade a conflict. They never create LIVE
/// by themselves. Name-only matches are never verified.
class TitleCandidate {
  const TitleCandidate({
    required this.name,
    required this.year,
    required this.contentType,
    this.externalId,
    this.imdbId,
    this.posterPath,
    this.alternateNames = const [],
    this.directors = const [],
    this.producers = const [],
    this.writers = const [],
  });

  final String name;
  final int? year;
  final String contentType;
  final String? externalId;
  final String? imdbId;
  final String? posterPath;
  final List<String> alternateNames;
  final List<String> directors;
  final List<String> producers;
  final List<String> writers;

  TitleCandidate copyWith({
    List<String>? directors,
    List<String>? producers,
    List<String>? writers,
    String? imdbId,
  }) {
    return TitleCandidate(
      name: name,
      year: year,
      contentType: contentType,
      externalId: externalId,
      imdbId: imdbId ?? this.imdbId,
      posterPath: posterPath,
      alternateNames: alternateNames,
      directors: directors ?? this.directors,
      producers: producers ?? this.producers,
      writers: writers ?? this.writers,
    );
  }
}

MatchConfidence classifyTitleMatch({
  required TitleIdentity query,
  required TitleCandidate candidate,
}) {
  final queryType = query.contentType.trim().toLowerCase();
  final candidateType = candidate.contentType.trim().toLowerCase();
  if (queryType != candidateType) {
    return MatchConfidence.noMatch;
  }

  if (query.hasExternalId &&
      ((candidate.externalId != null &&
              candidate.externalId!.trim().isNotEmpty &&
              _sameId(query, candidate.externalId!)) ||
          (candidate.imdbId != null &&
              candidate.imdbId!.trim().isNotEmpty &&
              _sameId(query, candidate.imdbId!)))) {
    return MatchConfidence.verifiedMatch;
  }

  if (!_namesMatch(query, candidate)) {
    return MatchConfidence.noMatch;
  }

  if (candidate.year == query.releaseYear) {
    if (_creditsConflict(query, candidate)) {
      return MatchConfidence.possibleMatch;
    }
    return MatchConfidence.verifiedMatch;
  }

  return MatchConfidence.possibleMatch;
}

MatchConfidence classifySearchResults({
  required TitleIdentity query,
  required List<TitleCandidate> candidates,
}) {
  if (uniqueVerifiedCandidate(query: query, candidates: candidates) != null) {
    return MatchConfidence.verifiedMatch;
  }
  if (candidates.isEmpty) {
    return MatchConfidence.noMatch;
  }

  final ranked = [
    for (final candidate in candidates)
      classifyTitleMatch(query: query, candidate: candidate),
  ];
  if (ranked.contains(MatchConfidence.possibleMatch) ||
      ranked.where((value) => value == MatchConfidence.verifiedMatch).length >
          1) {
    return MatchConfidence.possibleMatch;
  }
  return MatchConfidence.noMatch;
}

TitleCandidate? uniqueVerifiedCandidate({
  required TitleIdentity query,
  required List<TitleCandidate> candidates,
}) {
  final verified = [
    for (final candidate in candidates)
      if (classifyTitleMatch(query: query, candidate: candidate) ==
          MatchConfidence.verifiedMatch)
        candidate,
  ];
  if (verified.length == 1) {
    return verified.first;
  }
  if (verified.length > 1 && query.hasCredits) {
    final credited = [
      for (final candidate in verified)
        if (_creditsSupport(query, candidate)) candidate,
    ];
    if (credited.length == 1) {
      return credited.first;
    }
  }
  return null;
}

bool _namesMatch(TitleIdentity query, TitleCandidate candidate) {
  final candidateNames = <String>{
    normalizeTitleName(candidate.name),
    for (final name in candidate.alternateNames) normalizeTitleName(name),
  };
  if (candidateNames.contains(query.normalizedTitle)) {
    return true;
  }
  final alternate = query.normalizedAlternateTitle;
  return alternate != null && candidateNames.contains(alternate);
}

bool _creditsConflict(TitleIdentity query, TitleCandidate candidate) {
  return _creditConflicts(query.director, candidate.directors) ||
      _creditConflicts(query.producer, candidate.producers) ||
      _creditConflicts(query.writer, candidate.writers);
}

bool _creditsSupport(TitleIdentity query, TitleCandidate candidate) {
  return _creditMatches(query.director, candidate.directors) ||
      _creditMatches(query.producer, candidate.producers) ||
      _creditMatches(query.writer, candidate.writers);
}

bool _creditConflicts(String? query, List<String> candidateCredits) {
  if (query == null || query.trim().isEmpty) {
    return false;
  }
  if (candidateCredits.isEmpty) {
    return false;
  }
  return !_creditMatches(query, candidateCredits);
}

bool _creditMatches(String? query, List<String> candidateCredits) {
  if (query == null || query.trim().isEmpty || candidateCredits.isEmpty) {
    return false;
  }
  final needle = normalizeCreditName(query);
  return candidateCredits.any(
    (credit) => normalizeCreditName(credit) == needle,
  );
}

bool _sameId(TitleIdentity query, String candidateId) {
  final normalized = candidateId.trim();
  return normalized == query.tmdbId?.trim() ||
      normalized == query.imdbId?.trim() ||
      normalized == query.availabilityProviderId?.trim();
}

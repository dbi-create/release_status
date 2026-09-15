import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';

class TitleCandidate {
  const TitleCandidate({
    required this.name,
    required this.year,
    required this.contentType,
    this.externalId,
  });

  final String name;
  final int? year;
  final String contentType;
  final String? externalId;
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

  final namesMatch =
      query.normalizedTitle == normalizeTitleName(candidate.name);
  if (!namesMatch) {
    return MatchConfidence.noMatch;
  }

  if (query.hasExternalId &&
      candidate.externalId != null &&
      candidate.externalId!.trim().isNotEmpty &&
      _sameId(query, candidate.externalId!)) {
    return MatchConfidence.verifiedMatch;
  }

  if (candidate.year == query.releaseYear) {
    return MatchConfidence.verifiedMatch;
  }

  return MatchConfidence.possibleMatch;
}

MatchConfidence classifySearchResults({
  required TitleIdentity query,
  required List<TitleCandidate> candidates,
}) {
  if (candidates.isEmpty) {
    return MatchConfidence.noMatch;
  }

  final ranked = [
    for (final candidate in candidates)
      classifyTitleMatch(query: query, candidate: candidate),
  ];

  final verifiedCount = ranked
      .where((confidence) => confidence == MatchConfidence.verifiedMatch)
      .length;
  if (verifiedCount == 1) {
    return MatchConfidence.verifiedMatch;
  }
  if (verifiedCount > 1) {
    return MatchConfidence.possibleMatch;
  }
  if (ranked.contains(MatchConfidence.possibleMatch)) {
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
  return null;
}

bool _sameId(TitleIdentity query, String candidateId) {
  final normalized = candidateId.trim();
  return normalized == query.tmdbId?.trim() ||
      normalized == query.imdbId?.trim() ||
      normalized == query.availabilityProviderId?.trim();
}

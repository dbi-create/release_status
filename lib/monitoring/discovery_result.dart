import 'package:release_status/models/match_confidence.dart';

/// One platform listing from a discovery source. Not a license claim.
class DiscoveredAvailability {
  const DiscoveredAvailability({
    required this.displayName,
    required this.sourceName,
    this.sourceProviderId,
    this.canonicalId,
    this.listingUrl,
    this.detail,
    this.countsAsLiveEvidence = true,
  });

  final String displayName;
  final String sourceName;
  final String? sourceProviderId;
  final String? canonicalId;
  final String? listingUrl;
  final String? detail;

  /// Watch-provider offers can go LIVE. A TMDb TV network cannot.
  final bool countsAsLiveEvidence;
}

/// Provider-neutral result of discovering every verified platform for a title.
class DiscoveryResult {
  const DiscoveryResult({
    required this.matchConfidence,
    required this.sourceName,
    this.checkedAt,
    this.matchedTmdbId,
    this.matchedImdbId,
    this.posterUrl,
    this.director,
    this.producer,
    this.writer,
    this.platforms = const [],
    this.failed = false,
    this.detail,
  });

  factory DiscoveryResult.unconfigured() {
    return const DiscoveryResult(
      matchConfidence: MatchConfidence.noMatch,
      sourceName: 'Not configured',
      detail: 'Availability checking is not configured.',
    );
  }

  factory DiscoveryResult.failed({
    required String sourceName,
    required String detail,
    DateTime? checkedAt,
  }) {
    return DiscoveryResult(
      matchConfidence: MatchConfidence.noMatch,
      sourceName: sourceName,
      checkedAt: checkedAt,
      failed: true,
      detail: detail,
    );
  }

  factory DiscoveryResult.unverified({
    required MatchConfidence matchConfidence,
    required String sourceName,
    required DateTime checkedAt,
    String? detail,
  }) {
    return DiscoveryResult(
      matchConfidence: matchConfidence,
      sourceName: sourceName,
      checkedAt: checkedAt,
      detail: detail,
    );
  }

  final MatchConfidence matchConfidence;
  final String sourceName;
  final DateTime? checkedAt;
  final String? matchedTmdbId;
  final String? matchedImdbId;
  final String? posterUrl;
  final String? director;
  final String? producer;
  final String? writer;
  final List<DiscoveredAvailability> platforms;
  final bool failed;
  final String? detail;

  bool get isVerified =>
      !failed && matchConfidence == MatchConfidence.verifiedMatch;
}

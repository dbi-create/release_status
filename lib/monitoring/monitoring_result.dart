import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/models/match_confidence.dart';
import 'package:release_status/models/platform_status.dart';

export 'package:release_status/models/match_confidence.dart';

class MonitoringResult {
  const MonitoringResult({
    required this.platformName,
    required this.status,
    required this.matchConfidence,
    required this.message,
    this.checkedAt,
    this.evidenceSource,
    this.evidenceUrl,
    this.detail,
    this.sourceName,
    this.checkFailed = false,
    this.isVerifiedAbsence = false,
    this.kind = MonitoringResultKind.other,
    this.posterUrl,
    this.matchedTmdbId,
    this.discoveredPlatforms = const [],
  });

  factory MonitoringResult.unconfigured(String platformName) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.waiting,
      matchConfidence: MatchConfidence.noMatch,
      message: 'Not detected yet',
      detail:
          'Availability checking is not configured. No external lookup was performed.',
      kind: MonitoringResultKind.unconfigured,
    );
  }

  factory MonitoringResult.failed({
    required String platformName,
    required String detail,
    DateTime? checkedAt,
    String? sourceName,
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.waiting,
      matchConfidence: MatchConfidence.noMatch,
      message: 'Could not complete this check',
      detail: detail,
      checkedAt: checkedAt,
      sourceName: sourceName,
      checkFailed: true,
      kind: MonitoringResultKind.failed,
    );
  }

  factory MonitoringResult.notVerified({
    required String platformName,
    required DateTime checkedAt,
    String message = 'Not detected yet',
    String? detail,
    MatchConfidence matchConfidence = MatchConfidence.noMatch,
    String? sourceName,
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.waiting,
      matchConfidence: matchConfidence,
      message: message,
      detail: detail,
      checkedAt: checkedAt,
      sourceName: sourceName,
      kind: matchConfidence == MatchConfidence.possibleMatch
          ? MonitoringResultKind.possibleMatch
          : MonitoringResultKind.noMatch,
    );
  }

  factory MonitoringResult.verifiedAbsence({
    required String platformName,
    required DateTime checkedAt,
    required String evidenceSource,
    String? evidenceUrl,
    String? detail,
    String? sourceName,
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.waiting,
      matchConfidence: MatchConfidence.verifiedMatch,
      message: 'Not detected yet',
      detail: detail,
      checkedAt: checkedAt,
      evidenceSource: evidenceSource,
      evidenceUrl: evidenceUrl,
      sourceName: sourceName ?? evidenceSource,
      isVerifiedAbsence: true,
      kind: MonitoringResultKind.verifiedAbsence,
    );
  }

  factory MonitoringResult.verifiedLive({
    required String platformName,
    required DateTime checkedAt,
    required String evidenceSource,
    String? evidenceUrl,
    String? detail,
    String? sourceName,
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.live,
      matchConfidence: MatchConfidence.verifiedMatch,
      message: 'Detected on $platformName',
      detail: detail,
      checkedAt: checkedAt,
      evidenceSource: evidenceSource,
      evidenceUrl: evidenceUrl,
      sourceName: sourceName ?? evidenceSource,
      kind: MonitoringResultKind.verifiedLive,
    );
  }

  /// User-typed platform/channel name.
  final String platformName;

  /// Proposed status from this check. Failures remain WAITING.
  final DistributionStatus status;

  final MatchConfidence matchConfidence;
  final String message;
  final String? detail;

  /// Set only when an actual lookup was attempted or completed.
  final DateTime? checkedAt;

  final String? evidenceSource;
  final String? evidenceUrl;
  final String? sourceName;
  final bool checkFailed;
  final bool isVerifiedAbsence;
  final MonitoringResultKind kind;
  final String? posterUrl;
  final String? matchedTmdbId;
  final List<DiscoveredPlatform> discoveredPlatforms;

  bool get isVerifiedLive =>
      !checkFailed &&
      !isVerifiedAbsence &&
      matchConfidence == MatchConfidence.verifiedMatch &&
      status == DistributionStatus.live &&
      evidenceSource != null;

  bool get hasVerifiedIdentity =>
      !checkFailed && matchConfidence == MatchConfidence.verifiedMatch;

  MonitoringResult withTitleDiscovery({
    String? posterUrl,
    String? matchedTmdbId,
    List<DiscoveredPlatform> discoveredPlatforms = const [],
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: status,
      matchConfidence: matchConfidence,
      message: message,
      checkedAt: checkedAt,
      evidenceSource: evidenceSource,
      evidenceUrl: evidenceUrl,
      detail: detail,
      sourceName: sourceName,
      checkFailed: checkFailed,
      isVerifiedAbsence: isVerifiedAbsence,
      kind: kind,
      posterUrl: posterUrl ?? this.posterUrl,
      matchedTmdbId: matchedTmdbId ?? this.matchedTmdbId,
      discoveredPlatforms: discoveredPlatforms,
    );
  }
}

enum MonitoringResultKind {
  unconfigured,
  failed,
  noMatch,
  possibleMatch,
  verifiedAbsence,
  verifiedLive,
  other,
}

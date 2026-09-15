import 'package:release_status/models/platform_status.dart';

enum MatchConfidence { noMatch, possibleMatch, verifiedMatch }

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
    this.checkFailed = false,
  });

  factory MonitoringResult.unconfigured(String platformName) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.waiting,
      matchConfidence: MatchConfidence.noMatch,
      message: 'Not yet verified',
      detail:
          'Availability provider is not configured. No external lookup was performed.',
    );
  }

  factory MonitoringResult.failed({
    required String platformName,
    required String detail,
    DateTime? checkedAt,
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.waiting,
      matchConfidence: MatchConfidence.noMatch,
      message: 'Check failed',
      detail: detail,
      checkedAt: checkedAt,
      checkFailed: true,
    );
  }

  factory MonitoringResult.notVerified({
    required String platformName,
    required DateTime checkedAt,
    String message = 'Not yet verified',
    String? detail,
    MatchConfidence matchConfidence = MatchConfidence.noMatch,
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.waiting,
      matchConfidence: matchConfidence,
      message: message,
      detail: detail,
      checkedAt: checkedAt,
    );
  }

  factory MonitoringResult.verifiedLive({
    required String platformName,
    required DateTime checkedAt,
    required String evidenceSource,
    String? evidenceUrl,
    String? detail,
  }) {
    return MonitoringResult(
      platformName: platformName,
      status: DistributionStatus.live,
      matchConfidence: MatchConfidence.verifiedMatch,
      message: 'Verified availability',
      detail: detail,
      checkedAt: checkedAt,
      evidenceSource: evidenceSource,
      evidenceUrl: evidenceUrl,
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
  final bool checkFailed;

  bool get isVerifiedLive =>
      !checkFailed &&
      matchConfidence == MatchConfidence.verifiedMatch &&
      status == DistributionStatus.live &&
      evidenceSource != null;
}

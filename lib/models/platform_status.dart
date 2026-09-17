import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/match_confidence.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status_event.dart';

enum DistributionStatus { live, waiting, originalNetwork, removed }

extension DistributionStatusLabel on DistributionStatus {
  String get label {
    switch (this) {
      case DistributionStatus.live:
        return 'LIVE';
      case DistributionStatus.waiting:
        return 'NOT LIVE';
      case DistributionStatus.originalNetwork:
        return 'AIRS ON';
      case DistributionStatus.removed:
        return 'REMOVED';
    }
  }
}

class PlatformStatus {
  const PlatformStatus({
    required this.platformName,
    required this.status,
    this.firstDetectedLabel,
    this.lastCheckedLabel,
    this.lastCheckedAt,
    this.firstDetectedAt,
    this.removedAt,
    this.statusMessage,
    this.statusDetail,
    this.evidenceSource,
    this.evidenceUrl,
    this.lastMonitoringSource,
    this.lastMatchConfidence,
    this.lastCheckFailed = false,
    this.consecutiveVerifiedAbsences = 0,
    this.history = const [],
    this.origin = PlatformOrigin.manual,
    this.licenseRelationship = LicenseRelationship.confirmedByUser,
    this.sourceProviderId,
  });

  /// A user-entered platform that has not been checked yet.
  const PlatformStatus.waiting(
    this.platformName, {
    this.origin = PlatformOrigin.manual,
    this.licenseRelationship = LicenseRelationship.confirmedByUser,
  }) : status = DistributionStatus.waiting,
       firstDetectedLabel = null,
       lastCheckedLabel = null,
       lastCheckedAt = null,
       firstDetectedAt = null,
       removedAt = null,
       statusMessage = null,
       statusDetail = null,
       evidenceSource = null,
       evidenceUrl = null,
       lastMonitoringSource = null,
       lastMatchConfidence = null,
       lastCheckFailed = false,
       consecutiveVerifiedAbsences = 0,
       history = const [],
       sourceProviderId = null;

  final String platformName;
  final DistributionStatus status;
  final String? firstDetectedLabel;
  final String? lastCheckedLabel;
  final DateTime? lastCheckedAt;
  final DateTime? firstDetectedAt;
  final DateTime? removedAt;
  final String? statusMessage;
  final String? statusDetail;
  final String? evidenceSource;
  final String? evidenceUrl;
  final String? lastMonitoringSource;
  final MatchConfidence? lastMatchConfidence;
  final bool lastCheckFailed;
  final int consecutiveVerifiedAbsences;
  final List<PlatformStatusEvent> history;
  final PlatformOrigin origin;
  final LicenseRelationship licenseRelationship;
  final String? sourceProviderId;

  /// True when a demonstration label or a real lookup timestamp exists.
  bool get hasBeenChecked => lastCheckedAt != null || lastCheckedLabel != null;

  bool get hasRealLookup => lastCheckedAt != null;

  bool get hasAvailabilityEvidence =>
      status == DistributionStatus.live && evidenceSource != null;

  bool get hasNeverHadRealCheck => lastCheckedAt == null;

  /// Live because the user said they saw it, or because a listing URL checked out.
  bool get isUserConfirmedAvailability =>
      status == DistributionStatus.live &&
      (evidenceSource == userConfirmedAvailabilitySource ||
          lastMonitoringSource == userConfirmedAvailabilitySource ||
          evidenceSource == listingUrlAvailabilitySource ||
          lastMonitoringSource == listingUrlAvailabilitySource);

  bool get canMarkSeenLive => status == DistributionStatus.waiting;

  bool get canRemoveUserConfirmedLive => isUserConfirmedAvailability;

  String get statusLabel => status.label;

  /// Waiting titles have not been detected yet.
  bool get hasBeenDetected =>
      status != DistributionStatus.waiting &&
      (firstDetectedLabel != null || firstDetectedAt != null);

  String? get displayFirstDetected {
    if (firstDetectedAt != null) {
      return formatStoredTimestamp(firstDetectedAt!);
    }
    return firstDetectedLabel;
  }

  PlatformStatus copyWith({
    String? platformName,
    DistributionStatus? status,
    String? firstDetectedLabel,
    String? lastCheckedLabel,
    DateTime? lastCheckedAt,
    DateTime? firstDetectedAt,
    DateTime? removedAt,
    bool clearRemovedAt = false,
    String? statusMessage,
    String? statusDetail,
    String? evidenceSource,
    String? evidenceUrl,
    String? lastMonitoringSource,
    MatchConfidence? lastMatchConfidence,
    bool? lastCheckFailed,
    int? consecutiveVerifiedAbsences,
    List<PlatformStatusEvent>? history,
    PlatformOrigin? origin,
    LicenseRelationship? licenseRelationship,
    String? sourceProviderId,
  }) {
    return PlatformStatus(
      platformName: platformName ?? this.platformName,
      status: status ?? this.status,
      firstDetectedLabel: firstDetectedLabel ?? this.firstDetectedLabel,
      lastCheckedLabel: lastCheckedLabel ?? this.lastCheckedLabel,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      firstDetectedAt: firstDetectedAt ?? this.firstDetectedAt,
      removedAt: clearRemovedAt ? null : removedAt ?? this.removedAt,
      statusMessage: statusMessage ?? this.statusMessage,
      statusDetail: statusDetail ?? this.statusDetail,
      evidenceSource: evidenceSource ?? this.evidenceSource,
      evidenceUrl: evidenceUrl ?? this.evidenceUrl,
      lastMonitoringSource: lastMonitoringSource ?? this.lastMonitoringSource,
      lastMatchConfidence: lastMatchConfidence ?? this.lastMatchConfidence,
      lastCheckFailed: lastCheckFailed ?? this.lastCheckFailed,
      consecutiveVerifiedAbsences:
          consecutiveVerifiedAbsences ?? this.consecutiveVerifiedAbsences,
      history: history ?? this.history,
      origin: origin ?? this.origin,
      licenseRelationship: licenseRelationship ?? this.licenseRelationship,
      sourceProviderId: sourceProviderId ?? this.sourceProviderId,
    );
  }
}

/// User-facing source for availability the filmmaker confirmed themselves.
const String userConfirmedAvailabilitySource = 'Confirmed by you';

/// User-facing source for a public listing URL this app fetched and checked.
const String listingUrlAvailabilitySource = 'Listing URL';

String formatStoredTimestamp(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = value.toLocal();
  final month = months[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} $month ${local.year}, $hour:$minute';
}

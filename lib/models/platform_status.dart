enum DistributionStatus { live, waiting, removed }

class PlatformStatus {
  const PlatformStatus({
    required this.platformName,
    required this.status,
    this.firstDetectedLabel,
    this.lastCheckedLabel,
    this.lastCheckedAt,
    this.statusMessage,
    this.statusDetail,
    this.evidenceSource,
    this.evidenceUrl,
    this.lastCheckFailed = false,
  });

  /// A licensed platform that has not been checked yet.
  const PlatformStatus.waiting(this.platformName)
    : status = DistributionStatus.waiting,
      firstDetectedLabel = null,
      lastCheckedLabel = null,
      lastCheckedAt = null,
      statusMessage = null,
      statusDetail = null,
      evidenceSource = null,
      evidenceUrl = null,
      lastCheckFailed = false;

  final String platformName;
  final DistributionStatus status;
  final String? firstDetectedLabel;
  final String? lastCheckedLabel;
  final DateTime? lastCheckedAt;
  final String? statusMessage;
  final String? statusDetail;
  final String? evidenceSource;
  final String? evidenceUrl;
  final bool lastCheckFailed;

  /// True when a demonstration label or a real lookup timestamp exists.
  bool get hasBeenChecked => lastCheckedAt != null || lastCheckedLabel != null;

  bool get hasRealLookup => lastCheckedAt != null;

  bool get hasAvailabilityEvidence =>
      status == DistributionStatus.live && evidenceSource != null;

  String get statusLabel {
    switch (status) {
      case DistributionStatus.live:
        return 'LIVE';
      case DistributionStatus.waiting:
        return 'WAITING';
      case DistributionStatus.removed:
        return 'REMOVED';
    }
  }

  /// Waiting titles have not been detected yet.
  bool get hasBeenDetected =>
      status != DistributionStatus.waiting && firstDetectedLabel != null;

  PlatformStatus copyWith({
    String? platformName,
    DistributionStatus? status,
    String? firstDetectedLabel,
    String? lastCheckedLabel,
    DateTime? lastCheckedAt,
    String? statusMessage,
    String? statusDetail,
    String? evidenceSource,
    String? evidenceUrl,
    bool? lastCheckFailed,
  }) {
    return PlatformStatus(
      platformName: platformName ?? this.platformName,
      status: status ?? this.status,
      firstDetectedLabel: firstDetectedLabel ?? this.firstDetectedLabel,
      lastCheckedLabel: lastCheckedLabel ?? this.lastCheckedLabel,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      statusMessage: statusMessage ?? this.statusMessage,
      statusDetail: statusDetail ?? this.statusDetail,
      evidenceSource: evidenceSource ?? this.evidenceSource,
      evidenceUrl: evidenceUrl ?? this.evidenceUrl,
      lastCheckFailed: lastCheckFailed ?? this.lastCheckFailed,
    );
  }
}

enum DistributionStatus { live, waiting, removed }

class PlatformStatus {
  const PlatformStatus({
    required this.platformName,
    required this.status,
    this.firstDetectedLabel,
    this.lastCheckedLabel,
  });

  /// A licensed platform that has not been checked yet.
  factory PlatformStatus.waiting(String platformName) {
    return PlatformStatus(
      platformName: platformName,
      status: DistributionStatus.waiting,
    );
  }

  final String platformName;
  final DistributionStatus status;
  final String? firstDetectedLabel;
  final String? lastCheckedLabel;

  /// True when a real or demonstration check has recorded a timestamp.
  bool get hasBeenChecked => lastCheckedLabel != null;

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
}

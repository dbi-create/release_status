enum DistributionStatus { live, waiting, removed }

class PlatformStatus {
  const PlatformStatus({
    required this.platformName,
    required this.status,
    this.firstDetectedLabel,
    required this.lastCheckedLabel,
  });

  final String platformName;
  final DistributionStatus status;
  final String? firstDetectedLabel;
  final String lastCheckedLabel;

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

import 'package:release_status/models/platform_status.dart';

/// A recorded status transition for one licensed platform.
class PlatformStatusEvent {
  const PlatformStatusEvent({
    required this.previousStatus,
    required this.newStatus,
    required this.timestamp,
    required this.sourceName,
    required this.reason,
    required this.fromAutomatedCheck,
  });

  final DistributionStatus? previousStatus;
  final DistributionStatus newStatus;
  final DateTime timestamp;
  final String sourceName;
  final String reason;
  final bool fromAutomatedCheck;

  Map<String, Object?> toJson() {
    return {
      'previousStatus': previousStatus?.name,
      'newStatus': newStatus.name,
      'timestamp': timestamp.toIso8601String(),
      'sourceName': sourceName,
      'reason': reason,
      'fromAutomatedCheck': fromAutomatedCheck,
    };
  }

  factory PlatformStatusEvent.fromJson(Map<String, Object?> json) {
    return PlatformStatusEvent(
      previousStatus: _statusFromName(json['previousStatus'] as String?),
      newStatus: _statusFromName(json['newStatus'] as String?)!,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sourceName: json['sourceName'] as String? ?? 'Unknown source',
      reason: json['reason'] as String? ?? '',
      fromAutomatedCheck: json['fromAutomatedCheck'] as bool? ?? false,
    );
  }
}

DistributionStatus? _statusFromName(String? name) {
  if (name == null || name.isEmpty) {
    return null;
  }
  for (final status in DistributionStatus.values) {
    if (status.name == name) {
      return status;
    }
  }
  return null;
}

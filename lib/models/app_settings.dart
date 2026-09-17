/// Local monitoring settings.
///
/// [nextCheckDue] is when the next check should run while this app is open.
/// This app does not check titles while it is closed.
class AppSettings {
  const AppSettings({
    this.monitoringEnabled = true,
    this.checkInterval = defaultCheckInterval,
    this.lastCompletedCheckAt,
    this.notificationsClearedAt,
    this.liveAlertsEnabled = true,
  });

  static const Duration defaultCheckInterval = Duration(hours: 24);

  static const List<Duration> intervalChoices = [
    Duration(hours: 6),
    Duration(hours: 12),
    Duration(hours: 24),
    Duration(hours: 48),
  ];

  final bool monitoringEnabled;
  final Duration checkInterval;
  final DateTime? lastCompletedCheckAt;
  final DateTime? notificationsClearedAt;
  final bool liveAlertsEnabled;

  DateTime? get nextCheckDue {
    if (!monitoringEnabled || lastCompletedCheckAt == null) {
      return null;
    }
    return lastCompletedCheckAt!.add(checkInterval);
  }

  bool get checksAreDue {
    final due = nextCheckDue;
    if (due == null) {
      return false;
    }
    return !DateTime.now().isBefore(due);
  }

  AppSettings copyWith({
    bool? monitoringEnabled,
    Duration? checkInterval,
    DateTime? lastCompletedCheckAt,
    DateTime? notificationsClearedAt,
    bool? liveAlertsEnabled,
    bool clearLastCompletedCheckAt = false,
  }) {
    return AppSettings(
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      checkInterval: checkInterval ?? this.checkInterval,
      lastCompletedCheckAt: clearLastCompletedCheckAt
          ? null
          : lastCompletedCheckAt ?? this.lastCompletedCheckAt,
      notificationsClearedAt:
          notificationsClearedAt ?? this.notificationsClearedAt,
      liveAlertsEnabled: liveAlertsEnabled ?? this.liveAlertsEnabled,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'monitoringEnabled': monitoringEnabled,
      'checkIntervalHours': checkInterval.inHours,
      'lastCompletedCheckAt': lastCompletedCheckAt?.toIso8601String(),
      'notificationsClearedAt': notificationsClearedAt?.toIso8601String(),
      'liveAlertsEnabled': liveAlertsEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const AppSettings();
    }
    final hours = json['checkIntervalHours'];
    return AppSettings(
      monitoringEnabled: json['monitoringEnabled'] as bool? ?? true,
      checkInterval: hours is int && hours > 0
          ? Duration(hours: hours)
          : defaultCheckInterval,
      lastCompletedCheckAt: json['lastCompletedCheckAt'] is String
          ? DateTime.tryParse(json['lastCompletedCheckAt'] as String)
          : null,
      notificationsClearedAt: json['notificationsClearedAt'] is String
          ? DateTime.tryParse(json['notificationsClearedAt'] as String)
          : null,
      liveAlertsEnabled: json['liveAlertsEnabled'] as bool? ?? true,
    );
  }
}

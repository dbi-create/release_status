import 'package:flutter/material.dart';

import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';

abstract class AvailabilityMonitor {
  const AvailabilityMonitor();

  /// False when this prototype cannot contact an availability source.
  bool get isConfigured;

  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  });
}

class UnconfiguredAvailabilityMonitor implements AvailabilityMonitor {
  const UnconfiguredAvailabilityMonitor();

  @override
  bool get isConfigured => false;

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    return MonitoringResult.unconfigured(licensedPlatform);
  }
}

class AvailabilityMonitorScope extends InheritedWidget {
  const AvailabilityMonitorScope({
    super.key,
    required this.monitor,
    required super.child,
  });

  final AvailabilityMonitor monitor;

  static AvailabilityMonitor of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AvailabilityMonitorScope>();
    assert(scope != null, 'AvailabilityMonitorScope not found in context');
    return scope!.monitor;
  }

  @override
  bool updateShouldNotify(AvailabilityMonitorScope oldWidget) {
    return oldWidget.monitor != monitor;
  }
}

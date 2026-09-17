import 'package:release_status/models/app_settings.dart';

/// Whether a check should run while this app is open.
///
/// Does not check titles while the app is closed. Failed or unconfigured
/// monitors never start a sweep.
bool scheduledCheckShouldRun({
  required AppSettings settings,
  required bool monitorConfigured,
  required bool hasTitles,
  required bool isChecking,
  DateTime? now,
}) {
  if (!settings.monitoringEnabled ||
      !monitorConfigured ||
      !hasTitles ||
      isChecking) {
    return false;
  }
  final last = settings.lastCompletedCheckAt;
  if (last == null) {
    return true;
  }
  final moment = now ?? DateTime.now();
  return !moment.isBefore(last.add(settings.checkInterval));
}

import 'package:release_status/models/app_settings.dart';

/// Whether a catalog check should run now.
///
/// On-device checks only happen while the app is open. The 12-hour server job
/// uses the same interval and still alerts a closed iPhone when a channel
/// becomes LIVE.
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

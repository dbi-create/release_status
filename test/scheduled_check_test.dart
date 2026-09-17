import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/app_settings.dart';
import 'package:release_status/monitoring/monitoring_scheduler.dart';
import 'package:release_status/monitoring/scheduled_check.dart';

void main() {
  final now = DateTime(2026, 9, 15, 15);

  test('scheduled checks run when monitoring is on and never completed', () {
    expect(
      scheduledCheckShouldRun(
        settings: const AppSettings(monitoringEnabled: true),
        monitorConfigured: true,
        hasTitles: true,
        isChecking: false,
        now: now,
      ),
      isTrue,
    );
  });

  test('scheduled checks run when the interval has elapsed', () {
    expect(
      scheduledCheckShouldRun(
        settings: AppSettings(
          monitoringEnabled: true,
          checkInterval: const Duration(hours: 6),
          lastCompletedCheckAt: now.subtract(const Duration(hours: 7)),
        ),
        monitorConfigured: true,
        hasTitles: true,
        isChecking: false,
        now: now,
      ),
      isTrue,
    );
  });

  test('scheduled checks wait until the interval elapses', () {
    expect(
      scheduledCheckShouldRun(
        settings: AppSettings(
          monitoringEnabled: true,
          checkInterval: const Duration(hours: 6),
          lastCompletedCheckAt: now.subtract(const Duration(hours: 1)),
        ),
        monitorConfigured: true,
        hasTitles: true,
        isChecking: false,
        now: now,
      ),
      isFalse,
    );
  });

  test('scheduled checks do not run when monitoring is off', () {
    expect(
      scheduledCheckShouldRun(
        settings: const AppSettings(monitoringEnabled: false),
        monitorConfigured: true,
        hasTitles: true,
        isChecking: false,
        now: now,
      ),
      isFalse,
    );
  });

  test('scheduled checks do not run without a configured monitor', () {
    expect(
      scheduledCheckShouldRun(
        settings: const AppSettings(),
        monitorConfigured: false,
        hasTitles: true,
        isChecking: false,
        now: now,
      ),
      isFalse,
    );
  });

  test('scheduled checks do not run with an empty catalog', () {
    expect(
      scheduledCheckShouldRun(
        settings: const AppSettings(),
        monitorConfigured: true,
        hasTitles: false,
        isChecking: false,
        now: now,
      ),
      isFalse,
    );
  });

  test('scheduled checks do not start a second sweep while one is running', () {
    expect(
      scheduledCheckShouldRun(
        settings: const AppSettings(),
        monitorConfigured: true,
        hasTitles: true,
        isChecking: true,
        now: now,
      ),
      isFalse,
    );
  });

  test('scheduler tickNow runs the callback once', () async {
    var count = 0;
    final scheduler = MonitoringScheduler(
      startupDelay: const Duration(days: 1),
      pollInterval: const Duration(days: 1),
      onTick: () async {
        count += 1;
      },
    );
    await scheduler.tickNow();
    expect(count, 1);
    scheduler.dispose();
  });
}

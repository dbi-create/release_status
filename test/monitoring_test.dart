import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/screens/title_detail_screen.dart';

void main() {
  testWidgets('Check Status action appears', (tester) async {
    await _pumpApp(tester);

    await _openMarked(tester);

    expect(
      find.byKey(const ValueKey<String>('check-status-button')),
      findsOneWidget,
    );
    expect(find.text('Check Status'), findsOneWidget);
  });

  testWidgets('starting a check displays checking state', (tester) async {
    final gate = Completer<void>();
    final monitor = _ScriptedMonitor(gate: gate);

    await _pumpApp(tester, monitor: monitor);
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pump();

    expect(find.text('Checking…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('checking-status-indicator')),
      findsOneWidget,
    );
    expect(find.text('Checking public availability…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('repeated checks cannot be started simultaneously', (
    tester,
  ) async {
    final gate = Completer<void>();
    final monitor = _ScriptedMonitor(gate: gate);

    await _pumpApp(tester, monitor: monitor);
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pump();
    expect(monitor.callCount, 1);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pump();
    expect(monitor.callCount, 1);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('verified monitoring result changes WAITING to LIVE', (
    tester,
  ) async {
    await _pumpApp(tester, monitor: _relayVerifiedMonitor());
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TitleDetailScreen),
        matching: find.text('LIVE'),
      ),
      findsWidgets,
    );
    expect(find.text('Verified availability'), findsOneWidget);
    expect(find.text('Relay'), findsOneWidget);
    expect(find.text('WAITING'), findsWidgets);
  });

  testWidgets('unverified result remains WAITING', (tester) async {
    await _pumpApp(
      tester,
      monitor: _ScriptedMonitor(
        resultsByPlatform: {
          for (final platform in _markedPlatforms)
            platform: MonitoringResult.notVerified(
              platformName: platform,
              checkedAt: DateTime(2026, 9, 14, 18),
            ),
        },
      ),
    );
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TitleDetailScreen),
        matching: find.text('LIVE'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(TitleDetailScreen),
        matching: find.text('REMOVED'),
      ),
      findsNothing,
    );
    expect(find.text('WAITING'), findsWidgets);
    expect(find.text('Not yet verified'), findsWidgets);
    expect(find.text('0 of 5 platforms live'), findsWidgets);
  });

  testWidgets('possible match remains WAITING', (tester) async {
    await _pumpApp(
      tester,
      monitor: _ScriptedMonitor(
        resultsByPlatform: {
          for (final platform in _markedPlatforms)
            platform: MonitoringResult.notVerified(
              platformName: platform,
              checkedAt: DateTime(2026, 9, 14, 18),
              message: 'Possible match — verification required',
              matchConfidence: MatchConfidence.possibleMatch,
            ),
        },
      ),
    );
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TitleDetailScreen),
        matching: find.text('LIVE'),
      ),
      findsNothing,
    );
    expect(find.text('WAITING'), findsWidgets);
    expect(find.text('Possible match — verification required'), findsWidgets);
    expect(find.text('0 of 5 platforms live'), findsWidgets);
  });

  testWidgets('failed check does not mark platform unavailable', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      monitor: _ScriptedMonitor(
        resultsByPlatform: {
          for (final platform in _markedPlatforms)
            platform: MonitoringResult.failed(
              platformName: platform,
              checkedAt: DateTime(2026, 9, 14, 18),
              detail: 'Could not reach the availability source.',
            ),
        },
      ),
    );
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TitleDetailScreen),
        matching: find.text('REMOVED'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(TitleDetailScreen),
        matching: find.text('LIVE'),
      ),
      findsNothing,
    );
    expect(find.text('WAITING'), findsWidgets);
    expect(find.text('Check failed'), findsWidgets);
    expect(find.text('Could not reach the availability source.'), findsWidgets);
    expect(find.text('0 of 5 platforms live'), findsWidgets);
  });

  testWidgets('LIVE result updates title live count', (tester) async {
    await _pumpApp(tester, monitor: _relayVerifiedMonitor());
    await _openMarked(tester);

    expect(find.text('0 of 5 platforms live'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pumpAndSettle();

    expect(find.text('1 of 5 platforms live'), findsWidgets);
    expect(find.text('0 of 5 platforms live'), findsNothing);
  });

  testWidgets('LIVE result updates dashboard counts', (tester) async {
    await _pumpApp(tester, monitor: _relayVerifiedMonitor());
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1 live  ·  4 waiting'), findsOneWidget);
  });

  testWidgets('LIVE result can carry evidence source and URL', (tester) async {
    await _pumpApp(tester, monitor: _relayVerifiedMonitor());
    await _openMarked(tester);

    await tester.tap(find.byKey(const ValueKey<String>('check-status-button')));
    await tester.pumpAndSettle();

    expect(find.text('Evidence  Test Evidence Source'), findsOneWidget);
    expect(find.text('https://example.invalid/relay/marked'), findsOneWidget);
  });

  testWidgets('unchecked platform has no fake detection data', (tester) async {
    await _pumpApp(tester);
    await _openMarked(tester);

    expect(find.text('Relay'), findsOneWidget);
    expect(find.text('WAITING'), findsWidgets);
    expect(find.text('Verified availability'), findsNothing);
    expect(find.textContaining('Evidence'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.text('First Detected'), findsNothing);
    expect(find.text('Monitoring has not started'), findsWidgets);
  });
}

const _markedPlatforms = ['Amazon', 'PLEX', 'Fawesome', 'Ofive+', 'Relay'];

_ScriptedMonitor _relayVerifiedMonitor() {
  return _ScriptedMonitor(
    resultsByPlatform: {
      for (final platform in _markedPlatforms)
        if (platform == 'Relay')
          platform: MonitoringResult.verifiedLive(
            platformName: 'Relay',
            checkedAt: DateTime(2026, 9, 14, 18),
            evidenceSource: 'Test Evidence Source',
            evidenceUrl: 'https://example.invalid/relay/marked',
          )
        else
          platform: MonitoringResult.notVerified(
            platformName: platform,
            checkedAt: DateTime(2026, 9, 14, 18),
          ),
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  AvailabilityMonitor? monitor,
}) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ReleaseStatusApp(
      availabilityMonitor: monitor ?? const UnconfiguredAvailabilityMonitor(),
    ),
  );
}

Future<void> _openMarked(WidgetTester tester) async {
  final viewStatus = find.byKey(const ValueKey<String>('view-status-marked'));
  await tester.ensureVisible(viewStatus);
  await tester.tap(viewStatus);
  await tester.pumpAndSettle();
}

class _ScriptedMonitor implements AvailabilityMonitor {
  _ScriptedMonitor({this.resultsByPlatform = const {}, this.gate});

  final Map<String, MonitoringResult> resultsByPlatform;
  final Completer<void>? gate;
  int callCount = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    callCount += 1;
    final pending = gate;
    if (pending != null && !pending.isCompleted) {
      await pending.future;
    }
    return resultsByPlatform[licensedPlatform] ??
        MonitoringResult.notVerified(
          platformName: licensedPlatform,
          checkedAt: DateTime(2026, 9, 14, 18),
        );
  }
}

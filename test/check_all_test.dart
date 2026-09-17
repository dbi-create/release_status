import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/notifications/live_alert.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  test('check all updates every title sequentially', () async {
    final monitor = _RecordingMonitor();
    final catalog = TitleCatalog(
      initialTitles: const [
        ReleaseTitle(
          id: 'a',
          name: 'Alpha',
          releaseYear: 2020,
          contentType: 'Movie',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [PlatformStatus.waiting('Netflix')],
        ),
        ReleaseTitle(
          id: 'b',
          name: 'Beta',
          releaseYear: 2021,
          contentType: 'Movie',
          placeholderColor: Color(0xFF4A5340),
          platforms: [PlatformStatus.waiting('Plex')],
        ),
      ],
    );

    await catalog.checkAllTitles(monitor);

    expect(monitor.calls, ['Alpha:Netflix', 'Beta:Plex']);
    expect(
      catalog.titleById('a')!.platforms.single.status,
      DistributionStatus.live,
    );
    expect(
      catalog.titleById('b')!.platforms.single.status,
      DistributionStatus.live,
    );
    expect(catalog.livePlatformCount, 2);
    expect(catalog.settings.lastCompletedCheckAt, isNotNull);
    expect(catalog.checkProgress!.completed, isTrue);
    expect(catalog.checkProgress!.nowLiveNames, ['Netflix', 'Plex']);
    expect(catalog.checkProgress!.label, contains('2 now live'));
  });

  test('check all notifies when platforms become live', () async {
    final monitor = _RecordingMonitor();
    final alerts = <LiveAlert>[];
    final catalog = TitleCatalog(
      initialTitles: const [
        ReleaseTitle(
          id: 'a',
          name: 'Alpha',
          releaseYear: 2020,
          contentType: 'Movie',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [PlatformStatus.waiting('Netflix')],
        ),
      ],
    )..onTitlesWentLive = (wentLive) async {
        alerts.addAll(wentLive);
      };

    await catalog.checkAllTitles(monitor);

    expect(alerts, hasLength(1));
    expect(alerts.single.titleName, 'Alpha');
    expect(alerts.single.platformName, 'Netflix');
  });

  test('live alerts can be disabled', () async {
    final monitor = _RecordingMonitor();
    var called = false;
    final catalog = TitleCatalog(
      initialSnapshot: const CatalogSnapshot(
        existedOnDisk: true,
        createdCount: 1,
        titles: [
          ReleaseTitle(
            id: 'a',
            name: 'Alpha',
            releaseYear: 2020,
            contentType: 'Movie',
            placeholderColor: Color(0xFF3A4A63),
            platforms: [PlatformStatus.waiting('Netflix')],
          ),
        ],
        settings: AppSettings(liveAlertsEnabled: false),
      ),
    )..onTitlesWentLive = (_) async {
        called = true;
      };

    await catalog.checkAllTitles(monitor);
    expect(called, isFalse);
  });

  test('one failed title does not abort check all', () async {
    final monitor = _RecordingMonitor(failTitles: {'Beta'});
    final catalog = TitleCatalog(
      initialTitles: const [
        ReleaseTitle(
          id: 'a',
          name: 'Alpha',
          releaseYear: 2020,
          contentType: 'Movie',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [PlatformStatus.waiting('Netflix')],
        ),
        ReleaseTitle(
          id: 'b',
          name: 'Beta',
          releaseYear: 2021,
          contentType: 'Movie',
          placeholderColor: Color(0xFF4A5340),
          platforms: [PlatformStatus.waiting('Plex')],
        ),
        ReleaseTitle(
          id: 'c',
          name: 'Gamma',
          releaseYear: 2022,
          contentType: 'Movie',
          placeholderColor: Color(0xFF2F4A4E),
          platforms: [PlatformStatus.waiting('Amazon')],
        ),
      ],
    );

    await catalog.checkAllTitles(monitor);

    expect(monitor.calls, ['Alpha:Netflix', 'Beta:Plex', 'Gamma:Amazon']);
    expect(
      catalog.titleById('a')!.platforms.single.status,
      DistributionStatus.live,
    );
    expect(catalog.titleById('b')!.platforms.single.lastCheckFailed, isTrue);
    expect(
      catalog.titleById('b')!.platforms.single.status,
      DistributionStatus.waiting,
    );
    expect(
      catalog.titleById('c')!.platforms.single.status,
      DistributionStatus.live,
    );
    expect(catalog.checkProgress!.failedTitleNames, ['Beta']);
  });

  test('duplicate check all is ignored while busy', () async {
    final gate = Completer<void>();
    final monitor = _RecordingMonitor(gate: gate);
    final catalog = TitleCatalog(
      initialTitles: const [
        ReleaseTitle(
          id: 'a',
          name: 'Alpha',
          releaseYear: 2020,
          contentType: 'Movie',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [PlatformStatus.waiting('Netflix')],
        ),
      ],
    );

    final first = catalog.checkAllTitles(monitor);
    final second = catalog.checkAllTitles(monitor);
    gate.complete();
    await Future.wait([first, second]);
    expect(monitor.calls, ['Alpha:Netflix']);
  });

  testWidgets('Check All Titles runs from the dashboard', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ReleaseStatusApp(
        availabilityMonitor: _RecordingMonitor(),
        catalogStore: MemoryCatalogStore(
          initial: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        ),
        initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        initialTitles: const [
          ReleaseTitle(
            id: 'a',
            name: 'Alpha',
            releaseYear: 2020,
            contentType: 'Movie',
            placeholderColor: Color(0xFF3A4A63),
            platforms: [PlatformStatus.waiting('Netflix')],
            pinned: true,
          ),
        ],
      ),
    );

    expect(find.text('ADDED TITLES'), findsOneWidget);
    expect(find.text('LIVE CHANNELS'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('check-all-titles-button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('view-status-a')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Netflix - Added Manually'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
  });
}

class _RecordingMonitor implements AvailabilityMonitor {
  _RecordingMonitor({this.failTitles = const {}, this.gate});

  final Set<String> failTitles;
  final Completer<void>? gate;
  final List<String> calls = [];

  @override
  String get sourceId => 'test';

  @override
  String get displayName => 'Test source';

  @override
  bool get isConfigured => true;

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    final pending = gate;
    if (pending != null && !pending.isCompleted) {
      await pending.future;
    }
    calls.add('${title.title}:$licensedPlatform');
    if (failTitles.contains(title.title)) {
      throw Exception('provider unavailable');
    }
    return MonitoringResult.verifiedLive(
      platformName: licensedPlatform,
      checkedAt: DateTime(2026, 9, 14, 18),
      evidenceSource: 'Test source',
    );
  }
}

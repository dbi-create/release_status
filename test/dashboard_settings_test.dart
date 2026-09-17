import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/catalog_attention.dart';
import 'package:release_status/state/title_catalog.dart';

void main() {
  test('dashboard totals count licensed, live, waiting, and removed', () {
    final catalog = TitleCatalog(
      initialTitles: const [
        ReleaseTitle(
          id: 'a',
          name: 'Alpha',
          releaseYear: 2020,
          contentType: 'Movie',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [
            PlatformStatus(
              platformName: 'Netflix',
              status: DistributionStatus.live,
            ),
            PlatformStatus.waiting('Plex'),
            PlatformStatus(
              platformName: 'Amazon',
              status: DistributionStatus.removed,
            ),
          ],
        ),
      ],
    );

    expect(catalog.totalTitleCount, 1);
    expect(catalog.licensedPlatformCount, 3);
    expect(catalog.livePlatformCount, 1);
    expect(catalog.liveOrOnAirPlatformCount, 1);
    expect(catalog.waitingPlatformCount, 1);
    expect(catalog.removedPlatformCount, 1);
  });

  test('LIVE CHANNELS includes AIRS ON original networks', () {
    final catalog = TitleCatalog(
      initialTitles: const [
        ReleaseTitle(
          id: 'rookie',
          name: 'The Rookie',
          releaseYear: 2018,
          contentType: 'TV Series',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [
            PlatformStatus(
              platformName: 'Hulu',
              status: DistributionStatus.live,
            ),
            PlatformStatus(
              platformName: 'ABC',
              status: DistributionStatus.originalNetwork,
            ),
            PlatformStatus(
              platformName: 'NBC',
              status: DistributionStatus.originalNetwork,
            ),
            PlatformStatus.waiting('Plex'),
          ],
        ),
      ],
    );

    expect(catalog.livePlatformCount, 1);
    expect(catalog.liveOrOnAirPlatformCount, 3);
  });

  test(
    'attention groups lookups by title, including zero channels',
    () {
      final now = DateTime(2026, 9, 14);
      final attention = catalogAttention([
        ReleaseTitle(
          id: 'marked',
          name: 'Marked',
          releaseYear: 2026,
          contentType: 'TV Series',
          placeholderColor: const Color(0xFF3A4A63),
          platforms: const [],
          tmdbId: '335294',
          lastLookedUpAt: now,
        ),
        ReleaseTitle(
          id: 'rookie',
          name: 'The Rookie',
          releaseYear: 2018,
          contentType: 'TV Series',
          placeholderColor: const Color(0xFF4A5340),
          lastLookedUpAt: now,
          platforms: [
            PlatformStatus(
              platformName: 'Netflix',
              status: DistributionStatus.live,
              lastCheckedAt: now,
            ),
            PlatformStatus(
              platformName: 'Hulu',
              status: DistributionStatus.live,
              lastCheckedAt: now,
            ),
          ],
        ),
        ReleaseTitle(
          id: 'unchecked',
          name: 'Unchecked',
          releaseYear: 2020,
          contentType: 'Movie',
          placeholderColor: const Color(0xFF2F4A4E),
          platforms: const [PlatformStatus.waiting('Relay')],
        ),
      ]);

      expect(attention.discoveredByTitle, hasLength(2));
      expect(
        attention.discoveredByTitle.map((item) => item.summary).toList(),
        [
          'Marked is on 0 platforms.',
          'The Rookie is on 2 platforms.',
        ],
      );
      expect(attention.notificationCount, 2);
    },
  );

  testWidgets('settings can change monitoring interval', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('ReleaseStatus'), findsWidgets);
    expect(
      find.text('Your titles. Your platforms. Your status.'),
      findsWidgets,
    );
    expect(find.text('Monitoring enabled'), findsOneWidget);
    expect(
      find.textContaining('While this app is open, checks run on this schedule'),
      findsOneWidget,
    );
    expect(find.text('Notify when titles go live'), findsOneWidget);
    expect(find.text('Send test notification'), findsOneWidget);
    expect(find.text('Export catalog'), findsOneWidget);
    expect(find.text('Export status report'), findsOneWidget);
    expect(find.text('Restore last backup'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('check-interval-12')));
    await tester.pump();

    final catalog = TitleCatalogScope.of(
      tester.element(find.text('Monitoring enabled')),
    );
    expect(catalog.settings.checkInterval, const Duration(hours: 12));
  });

  test('app settings next check due uses the stored interval', () {
    final settings = AppSettings(
      monitoringEnabled: true,
      checkInterval: const Duration(hours: 24),
      lastCompletedCheckAt: DateTime(2026, 9, 13),
    );
    expect(settings.nextCheckDue, DateTime(2026, 9, 14));
    expect(settings.copyWith(monitoringEnabled: false).nextCheckDue, isNull);
  });
}

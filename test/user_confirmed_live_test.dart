import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/removal_policy.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  final confirmedAt = DateTime(2026, 9, 15, 9);

  test('user confirmation marks a manual platform LIVE', () {
    final catalog = TitleCatalog(
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
      initialTitles: const [
        ReleaseTitle(
          id: 'marked',
          name: 'MARKED',
          releaseYear: 2026,
          contentType: 'TV Series',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [PlatformStatus.waiting('Relay')],
        ),
      ],
    );

    catalog.markPlatformSeenLive(
      titleId: 'marked',
      platformName: 'Relay',
      listingUrl: 'https://example.invalid/relay/marked',
      confirmedAt: confirmedAt,
    );

    final platform = catalog.titleById('marked')!.platforms.single;
    expect(platform.status, DistributionStatus.live);
    expect(platform.origin, PlatformOrigin.manual);
    expect(
      platform.licenseRelationship,
      LicenseRelationship.confirmedByUser,
    );
    expect(platform.evidenceSource, userConfirmedAvailabilitySource);
    expect(platform.lastMonitoringSource, userConfirmedAvailabilitySource);
    expect(platform.evidenceUrl, 'https://example.invalid/relay/marked');
    expect(platform.isUserConfirmedAvailability, isTrue);
    expect(platform.history, hasLength(1));
    expect(platform.history.single.fromAutomatedCheck, isFalse);
    expect(platform.firstDetectedAt, confirmedAt);
  });

  test('user confirmation does not require a listing URL', () {
    final updated = applyUserConfirmedLive(
      PlatformStatus.waiting('Ofive+'),
      confirmedAt: confirmedAt,
    );
    expect(updated.status, DistributionStatus.live);
    expect(updated.evidenceUrl, isNull);
    expect(updated.evidenceSource, userConfirmedAvailabilitySource);
  });

  test('repeating user confirmation does not duplicate history', () {
    var platform = applyUserConfirmedLive(
      PlatformStatus.waiting('Relay'),
      confirmedAt: confirmedAt,
    );
    platform = applyUserConfirmedLive(
      platform,
      confirmedAt: confirmedAt.add(const Duration(hours: 1)),
      listingUrl: 'https://example.invalid/relay/marked',
    );
    expect(platform.history, hasLength(1));
    expect(platform.evidenceUrl, 'https://example.invalid/relay/marked');
  });

  test('TMDb absence does not remove user-confirmed LIVE', () {
    var platform = applyUserConfirmedLive(
      PlatformStatus.waiting('Relay'),
      confirmedAt: confirmedAt,
    );
    const policy = RemovalConfirmationPolicy(
      requiredConsecutiveVerifiedAbsences: 3,
    );
    for (var i = 0; i < 3; i++) {
      platform = applyMonitoringResult(
        platform,
        MonitoringResult.verifiedAbsence(
          platformName: 'Relay',
          checkedAt: confirmedAt.add(Duration(days: i + 1)),
          evidenceSource: 'TMDb Watch Providers',
          sourceName: 'TMDb Watch Providers',
        ),
        removalPolicy: policy,
      );
    }
    expect(platform.status, DistributionStatus.live);
    expect(platform.isUserConfirmedAvailability, isTrue);
    expect(platform.consecutiveVerifiedAbsences, 0);
    expect(platform.lastMonitoringSource, userConfirmedAvailabilitySource);
  });

  test('independent TMDb LIVE can still replace user confirmation source', () {
    final platform = applyMonitoringResult(
      applyUserConfirmedLive(
        PlatformStatus.waiting('Plex'),
        confirmedAt: confirmedAt,
      ),
      MonitoringResult.verifiedLive(
        platformName: 'Plex',
        checkedAt: confirmedAt.add(const Duration(days: 1)),
        evidenceSource: 'TMDb Watch Providers',
        sourceName: 'TMDb Watch Providers',
      ),
    );
    expect(platform.status, DistributionStatus.live);
    expect(platform.isUserConfirmedAvailability, isFalse);
    expect(platform.evidenceSource, 'TMDb Watch Providers');
    expect(platform.origin, PlatformOrigin.manual);
  });

  test('user-confirmed LIVE persists', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    first.addTitle(
      name: 'MARKED',
      contentType: 'TV Series',
      releaseYear: 2026,
      platformNames: const ['Relay'],
    );
    first.markPlatformSeenLive(
      titleId: first.titles.single.id,
      platformName: 'Relay',
      listingUrl: 'https://example.invalid/relay/marked',
      confirmedAt: confirmedAt,
    );
    await first.persistCompleted;

    final loaded = decodeCatalogSnapshot(
      encodeCatalogSnapshot(first.snapshot),
      existedOnDisk: true,
    );
    final platform = loaded.titles.single.platforms.single;
    expect(platform.status, DistributionStatus.live);
    expect(platform.evidenceSource, userConfirmedAvailabilitySource);
    expect(platform.evidenceUrl, 'https://example.invalid/relay/marked');
    expect(platform.origin, PlatformOrigin.manual);
  });

  testWidgets('Mark as seen live records Relay without treating it as TMDb', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ReleaseStatusApp(
        catalogStore: MemoryCatalogStore(
          initial: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        ),
        initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        initialTitles: const [
          ReleaseTitle(
            id: 'marked',
            name: 'MARKED',
            releaseYear: 2026,
            contentType: 'TV Series',
            placeholderColor: Color(0xFF3A4A63),
            platforms: [PlatformStatus.waiting('Relay')],
            pinned: true,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('view-status-marked')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('mark-seen-live-Relay')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not an independent listing from TMDb'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('listing-url-field')),
      'https://example.invalid/relay/marked',
    );
    await tester.tap(find.byKey(const ValueKey<String>('confirm-seen-live-button')));
    await tester.pumpAndSettle();

    expect(find.text('LIVE'), findsWidgets);
    expect(find.textContaining('Relay - Added Manually'), findsOneWidget);
    expect(find.textContaining('Source: Confirmed by you'), findsNothing);
    expect(
      find.textContaining('https://example.invalid/relay/marked'),
      findsNothing,
    );
    expect(find.textContaining('Added Manually'), findsOneWidget);
    expect(find.text('Remove Live Status'), findsNothing);
    expect(find.text('Mark as seen live'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('edit-title-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Source: Confirmed by you'), findsNothing);
    expect(find.textContaining('Source: https://example.invalid/relay/marked'), findsOneWidget);
    expect(find.text('Remove Live Status'), findsOneWidget);
  });

  test('removing user confirmation returns the platform to waiting', () {
    final catalog = TitleCatalog(
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
      initialTitles: const [
        ReleaseTitle(
          id: 'marked',
          name: 'MARKED',
          releaseYear: 2026,
          contentType: 'TV Series',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [PlatformStatus.waiting('Relay')],
        ),
      ],
    );

    catalog.markPlatformSeenLive(
      titleId: 'marked',
      platformName: 'Relay',
      listingUrl: 'https://example.invalid/relay/marked',
      confirmedAt: confirmedAt,
    );
    catalog.removeUserConfirmedLive(
      titleId: 'marked',
      platformName: 'Relay',
      clearedAt: confirmedAt.add(const Duration(hours: 2)),
    );

    final platform = catalog.titleById('marked')!.platforms.single;
    expect(platform.status, DistributionStatus.waiting);
    expect(platform.isUserConfirmedAvailability, isFalse);
    expect(platform.canMarkSeenLive, isTrue);
    expect(platform.canRemoveUserConfirmedLive, isFalse);
    expect(platform.evidenceSource, isNull);
    expect(platform.evidenceUrl, isNull);
    expect(platform.firstDetectedAt, isNull);
    expect(platform.origin, PlatformOrigin.manual);
    expect(platform.history, hasLength(2));
    expect(platform.history.last.newStatus, DistributionStatus.waiting);
    expect(platform.history.last.fromAutomatedCheck, isFalse);
  });

  test('clearing confirmation does not change TMDb LIVE', () {
    final tmdbLive = applyMonitoringResult(
      PlatformStatus.waiting('Plex'),
      MonitoringResult.verifiedLive(
        platformName: 'Plex',
        checkedAt: confirmedAt,
        evidenceSource: 'TMDb Watch Providers',
        sourceName: 'TMDb Watch Providers',
      ),
    );
    final unchanged = applyClearUserConfirmedLive(
      tmdbLive,
      clearedAt: confirmedAt.add(const Duration(hours: 1)),
    );
    expect(unchanged.status, DistributionStatus.live);
    expect(unchanged.evidenceSource, 'TMDb Watch Providers');
    expect(unchanged.canRemoveUserConfirmedLive, isFalse);
  });

  testWidgets('Remove Live Status undoes a mistaken confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ReleaseStatusApp(
        catalogStore: MemoryCatalogStore(
          initial: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        ),
        initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        initialTitles: const [
          ReleaseTitle(
            id: 'marked',
            name: 'MARKED',
            releaseYear: 2026,
            contentType: 'TV Series',
            placeholderColor: Color(0xFF3A4A63),
            platforms: [PlatformStatus.waiting('Relay')],
            pinned: true,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('view-status-marked')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('mark-seen-live-Relay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('confirm-seen-live-button')));
    await tester.pumpAndSettle();

    expect(find.text('Mark as seen live'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('edit-title-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('remove-live-status-Relay')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-remove-live-status-button')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-title-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('NOT LIVE'), findsWidgets);
    expect(find.textContaining('Relay - Added Manually'), findsOneWidget);
    expect(find.text('Mark as seen live'), findsOneWidget);
    expect(find.text('Remove Live Status'), findsNothing);
    expect(find.textContaining('https://example.invalid/relay/marked'), findsNothing);
  });
}

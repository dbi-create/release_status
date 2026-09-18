import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/discovered_listings.dart';
import 'package:release_status/monitoring/discovery_monitor.dart';
import 'package:release_status/monitoring/discovery_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_lookup.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  test('TMDb watch listings go live; original networks air on', () {
    final current = [
      PlatformStatus.waiting('Prime Video'),
    ];
    final merged = applyDiscoveredPlatforms(
      current: current,
      listings: const [
        DiscoveredAvailability(
          displayName: 'Amazon Prime Video',
          sourceName: 'TMDb Watch Providers',
          sourceProviderId: '9',
        ),
        DiscoveredAvailability(
          displayName: 'Netflix',
          sourceName: 'TMDb Watch Providers',
          sourceProviderId: '8',
        ),
        DiscoveredAvailability(
          displayName: 'Plex',
          sourceName: 'TMDb Watch Providers',
        ),
        DiscoveredAvailability(
          displayName: 'HBO',
          sourceName: 'TMDb Networks',
          countsAsLiveEvidence: false,
          detail:
              'TMDb lists HBO as the original network. This is not a current US watch offer.',
        ),
      ],
      checkedAt: DateTime.utc(2026, 9, 16, 12),
    );

    expect(merged, hasLength(4));
    expect(merged.first.platformName, 'Amazon Prime Video');
    expect(merged.first.origin, PlatformOrigin.automatic);
    expect(merged.first.status, DistributionStatus.live);
    expect(
      merged.map((platform) => platform.platformName),
      containsAll(<String>['Netflix', 'Plex', 'HBO']),
    );
    final netflix = merged.firstWhere(
      (platform) => platform.platformName == 'Netflix',
    );
    expect(netflix.status, DistributionStatus.live);
    expect(netflix.origin, PlatformOrigin.automatic);
    expect(netflix.licenseRelationship, LicenseRelationship.unknown);
    final hbo = merged.firstWhere(
      (platform) => platform.platformName == 'HBO',
    );
    expect(hbo.status, DistributionStatus.originalNetwork);
    expect(hbo.origin, PlatformOrigin.automatic);
  });

  test('manual storefront URL merges with a later TMDb name', () {
    final merged = applyDiscoveredPlatforms(
      current: [
        PlatformStatus.waiting('My Stream').copyWith(
          evidenceUrl: 'https://watch.plex.tv/show/harbor-light',
        ),
      ],
      listings: const [
        DiscoveredAvailability(
          displayName: 'Plex',
          sourceName: 'TMDb Watch Providers',
          sourceProviderId: '209',
          listingUrl: 'https://www.justwatch.com/us/tv-show/harbor-light',
        ),
      ],
      checkedAt: DateTime.utc(2026, 9, 16, 12),
    );

    expect(merged, hasLength(1));
    expect(merged.single.platformName, 'Plex');
    expect(merged.single.status, DistributionStatus.live);
    expect(merged.single.origin, PlatformOrigin.automatic);
    expect(merged.single.licenseRelationship, LicenseRelationship.unknown);
    expect(merged.single.sourceProviderId, '209');
    expect(
      merged.single.evidenceUrl,
      'https://watch.plex.tv/show/harbor-light',
    );
  });

  testWidgets('picking a TMDb match loads US channels automatically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ReleaseStatusApp(
        availabilityMonitor: _FakeDiscoveryMonitor(),
        catalogStore: MemoryCatalogStore(
          initial: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        ),
        initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        initialTitles: const [],
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('add-manual-channel-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('add-platform-button')),
      findsNothing,
    );
    expect(find.text('Auto Populate'), findsNothing);
    expect(find.text('Load TMDb channels'), findsNothing);
    expect(find.text('SEARCH'), findsOneWidget);
    expect(find.text('SAVE TITLE'), findsOneWidget);
    expect(find.text('Licensed Platforms'), findsNothing);
    expect(find.text('+ Manual Channel'), findsNothing);
    expect(find.text('Channel TMDb does not list'), findsNothing);
    expect(find.text('Add Platform'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('title-name-field')),
      'Stranger Things',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('find-title-matches-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Licensed Platforms'), findsNothing);
    expect(find.text('+ Manual Channel'), findsNothing);
    expect(find.text('Select Correct Title'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('title-match-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Stranger Things  ·  TV Series  ·  2016').last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Plex'), findsOneWidget);
    expect(find.text('Licensed Platforms'), findsOneWidget);
    expect(find.text('+ Manual Channel'), findsOneWidget);
    expect(
      find.textContaining('Added Automatically', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('LIVE', findRichText: true), findsWidgets);
    expect(
      find.text(
        'Found 2 Channels.',
      ),
      findsOneWidget,
    );

    final catalog = TitleCatalogScope.of(
      tester.element(find.byKey(const ValueKey<String>('save-title-button'))),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-title-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
    await tester.pumpAndSettle();

    final title = catalog.titles.single;
    expect(title.platforms, hasLength(2));
    expect(
      title.platforms.every(
        (platform) => platform.status == DistributionStatus.live,
      ),
      isTrue,
    );
    expect(
      title.platforms.every(
        (platform) => platform.origin == PlatformOrigin.automatic,
      ),
      isTrue,
    );
    expect(title.tmdbId, '66732');
  });

  testWidgets('a name by itself cannot auto populate platforms', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ReleaseStatusApp(
        availabilityMonitor: _FakeDiscoveryMonitor(),
        catalogStore: MemoryCatalogStore(
          initial: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        ),
        initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
        initialTitles: const [],
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('title-name-field')),
      'MARKED',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('find-title-matches-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsNothing);
    expect(find.text('Licensed Platforms'), findsNothing);
    expect(find.text('+ Manual Channel'), findsNothing);
    expect(
      find.textContaining('No matching titles were found'),
      findsOneWidget,
    );
  });
}

class _FakeDiscoveryMonitor
    implements AvailabilityMonitor, DiscoveryMonitor, TitleLookup {
  @override
  bool get isConfigured => true;

  @override
  String get sourceId => 'test-discovery';

  @override
  String get displayName => 'TMDb Watch Providers';

  @override
  Future<List<TitleLookupMatch>> searchByName({
    required String name,
    String? contentType,
    int? year,
  }) async {
    if (name.trim().toLowerCase() != 'stranger things') {
      return const [];
    }
    return const [
      TitleLookupMatch(
        name: 'Stranger Things',
        contentType: 'TV Series',
        year: 2016,
        tmdbId: '66732',
      ),
    ];
  }

  @override
  Future<DiscoveryResult> discover({required TitleIdentity title}) async {
    expect(title.title, 'Stranger Things');
    expect(title.contentType, 'TV Series');
    expect(title.releaseYear, 2016);
    return const DiscoveryResult(
      matchConfidence: MatchConfidence.verifiedMatch,
      sourceName: 'TMDb Watch Providers',
      matchedTmdbId: '66732',
      platforms: [
        DiscoveredAvailability(
          displayName: 'Netflix',
          sourceName: 'TMDb Watch Providers',
        ),
        DiscoveredAvailability(
          displayName: 'Plex',
          sourceName: 'TMDb Watch Providers',
        ),
      ],
    );
  }

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    return MonitoringResult.unconfigured(licensedPlatform);
  }
}

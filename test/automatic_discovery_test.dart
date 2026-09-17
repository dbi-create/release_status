import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/composite_monitor.dart';
import 'package:release_status/monitoring/discovery_monitor.dart';
import 'package:release_status/monitoring/discovery_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/state/catalog_attention.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  final checkedAt = DateTime(2026, 9, 14, 18);

  ReleaseTitle emptyTitle({
    String id = 'st',
    String name = 'Stranger Things',
    List<PlatformStatus> platforms = const [],
    String? director,
    String? producer,
    String? writer,
    String? imdbId,
    String? tmdbId,
    DateTime? lastLookedUpAt,
  }) {
    return ReleaseTitle(
      id: id,
      name: name,
      releaseYear: 2016,
      contentType: 'TV Series',
      placeholderColor: const Color(0xFF3A4A63),
      platforms: platforms,
      director: director,
      producer: producer,
      writer: writer,
      imdbId: imdbId,
      tmdbId: tmdbId,
      lastLookedUpAt: lastLookedUpAt,
    );
  }

  DiscoveryResult verifiedDiscovery({
    List<DiscoveredAvailability> platforms = const [],
    String? tmdbId = '66732',
    String? imdbId = 'tt4574334',
    MatchConfidence confidence = MatchConfidence.verifiedMatch,
  }) {
    return DiscoveryResult(
      matchConfidence: confidence,
      sourceName: 'TMDb Watch Providers',
      checkedAt: checkedAt,
      matchedTmdbId: tmdbId,
      matchedImdbId: imdbId,
      platforms: platforms,
    );
  }

  DiscoveredAvailability listing(
    String name, {
    String? providerId,
    String source = 'TMDb Watch Providers',
  }) {
    return DiscoveredAvailability(
      displayName: name,
      sourceName: source,
      sourceProviderId: providerId,
      listingUrl: 'https://example.invalid/$name',
      detail: 'Listed as $name.',
    );
  }

  TitleCatalog catalogWith(List<ReleaseTitle> titles, {CatalogStore? store}) {
    return TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
      initialTitles: titles,
    );
  }

  test('director, producer, writer, IMDb ID, and TMDb ID persist', () async {
    final store = MemoryCatalogStore();
    final first = catalogWith(const [], store: store);
    first.addTitle(
      name: 'Harbor Light',
      contentType: 'Movie',
      releaseYear: 2022,
      platformNames: const ['Ofive+'],
      director: 'A Director',
      producer: 'A Producer',
      writer: 'A Writer',
      imdbId: 'tt1234567',
      tmdbId: '42',
    );
    await first.persistCompleted;

    final loaded = decodeCatalogSnapshot(
      encodeCatalogSnapshot(first.snapshot),
      existedOnDisk: true,
    );
    final title = loaded.titles.single;
    expect(title.director, 'A Director');
    expect(title.producer, 'A Producer');
    expect(title.writer, 'A Writer');
    expect(title.imdbId, 'tt1234567');
    expect(title.tmdbId, '42');
  });

  test('old JSON migrates missing identity and platform fields safely', () {
    const source = '''
{
  "schemaVersion": 1,
  "createdCount": 1,
  "titles": [
    {
      "id": "t1",
      "name": "Harbor Light",
      "releaseYear": 2022,
      "contentType": "Movie",
      "placeholderColor": 4281894499,
      "imdbId": "tt999",
      "platforms": [
        {
          "platformName": "Ofive+",
          "status": "waiting"
        }
      ]
    }
  ]
}
''';
    final loaded = decodeCatalogSnapshot(source, existedOnDisk: true);
    final title = loaded.titles.single;
    expect(title.director, isNull);
    expect(title.producer, isNull);
    expect(title.writer, isNull);
    expect(title.tmdbId, isNull);
    expect(title.imdbId, 'tt999');
    expect(title.platforms.single.origin, PlatformOrigin.manual);
    expect(
      title.platforms.single.licenseRelationship,
      LicenseRelationship.confirmedByUser,
    );
  });

  test('platform origin persists and old platforms default to MANUAL', () async {
    final first = catalogWith([
      emptyTitle(
        platforms: [
          PlatformStatus.waiting('Amazon'),
          PlatformStatus.waiting(
            'Netflix',
            origin: PlatformOrigin.automatic,
            licenseRelationship: LicenseRelationship.unknown,
          ),
        ],
      ),
    ], store: MemoryCatalogStore());
    await first.persistCompleted;

    final encoded = encodeCatalogSnapshot(first.snapshot);
    expect(encoded, contains('"origin": "manual"'));
    expect(encoded, contains('"origin": "automatic"'));
    final loaded = decodeCatalogSnapshot(encoded, existedOnDisk: true);
    expect(loaded.titles.single.platforms.first.origin, PlatformOrigin.manual);
    expect(
      loaded.titles.single.platforms.last.origin,
      PlatformOrigin.automatic,
    );
  });

  test('license relationship persists for manual and automatic platforms', () {
    final catalog = catalogWith([
      emptyTitle(platforms: [PlatformStatus.waiting('Ofive+')]),
    ]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(platforms: [listing('Plex', providerId: '209')]),
    );
    final ofive = catalog.titleById('st')!.platforms.first;
    final plex = catalog.titleById('st')!.platforms.last;
    expect(ofive.licenseRelationship, LicenseRelationship.confirmedByUser);
    expect(plex.licenseRelationship, LicenseRelationship.unknown);
    expect(plex.origin, PlatformOrigin.automatic);
    expect(plex.status, DistributionStatus.live);
  });

  test('manually added platform is CONFIRMED_BY_USER and WAITING', () {
    final catalog = catalogWith(const []);
    final title = catalog.addTitle(
      name: 'MARKED',
      contentType: 'TV Series',
      releaseYear: 2026,
      platformNames: const ['Ofive+'],
    );
    expect(title.platforms.single.origin, PlatformOrigin.manual);
    expect(
      title.platforms.single.licenseRelationship,
      LicenseRelationship.confirmedByUser,
    );
    expect(title.platforms.single.status, DistributionStatus.waiting);
  });

  test('discovery does not occur from POSSIBLE MATCH', () {
    final catalog = catalogWith([emptyTitle()]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(
        confidence: MatchConfidence.possibleMatch,
        platforms: [listing('Netflix')],
      ),
    );
    expect(catalog.titleById('st')!.platforms, isEmpty);
  });

  test('discovery does not occur from NO MATCH', () {
    final catalog = catalogWith([emptyTitle()]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(
        confidence: MatchConfidence.noMatch,
        platforms: [listing('Netflix')],
      ),
    );
    expect(catalog.titleById('st')!.platforms, isEmpty);
  });

  test('unknown provider can be added automatically', () {
    final catalog = catalogWith([emptyTitle()]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(
        platforms: [listing('Some New Streaming Channel', providerId: '9001')],
      ),
    );
    final platform = catalog.titleById('st')!.platforms.single;
    expect(platform.platformName, 'Some New Streaming Channel');
    expect(platform.status, DistributionStatus.live);
    expect(platform.origin, PlatformOrigin.automatic);
    expect(platform.sourceProviderId, '9001');
  });

  test('TMDb TV network is added as AIRS ON and never marked live', () {
    final catalog = catalogWith([emptyTitle()]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(
        platforms: [
          DiscoveredAvailability(
            displayName: 'VET Tv',
            sourceName: 'TMDb Network',
            countsAsLiveEvidence: false,
            detail:
                'TMDb lists VET Tv as the original network. This is not a current US watch offer.',
          ),
        ],
      ),
    );
    final platform = catalog.titleById('st')!.platforms.single;
    expect(platform.platformName, 'VET Tv');
    expect(platform.status, DistributionStatus.originalNetwork);
    expect(platform.canMarkSeenLive, isFalse);
    expect(platform.origin, PlatformOrigin.automatic);
    expect(platform.lastMonitoringSource, 'TMDb Network');
  });

  test('listing-URL LIVE is kept when TMDb only has the TV network', () {
    final live = applyVerifiedListingLive(
      PlatformStatus.waiting('VET TV'),
      checkedAt: checkedAt,
      listingUrl: 'https://example.invalid/vet-tv/marked-military',
    );
    final catalog = catalogWith([emptyTitle(platforms: [live])]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(
        platforms: [
          DiscoveredAvailability(
            displayName: 'VET Tv',
            sourceName: 'TMDb Network',
            countsAsLiveEvidence: false,
            detail:
                'TMDb lists VET Tv as the original network. This is not a current US watch offer.',
          ),
        ],
      ),
    );
    final platform = catalog.titleById('st')!.platforms.single;
    expect(platform.status, DistributionStatus.live);
    expect(platform.isUserConfirmedAvailability, isTrue);
  });

  test(
    'network-only match does not block removal of a TMDb watch-provider LIVE row',
    () {
      final live = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        MonitoringResult.verifiedLive(
          platformName: 'Netflix',
          checkedAt: checkedAt,
          evidenceSource: 'TMDb Watch Providers',
        ),
      );
      final catalog = catalogWith([emptyTitle(platforms: [live])]);
      final networkOnly = verifiedDiscovery(
        platforms: [
          DiscoveredAvailability(
            displayName: 'Netflix',
            sourceName: 'TMDb Network',
            countsAsLiveEvidence: false,
          ),
        ],
      );
      catalog.applyDiscovery('st', networkOnly);
      catalog.applyDiscovery('st', networkOnly);
      expect(
        catalog.titleById('st')!.platforms.single.status,
        DistributionStatus.live,
      );
      catalog.applyDiscovery('st', networkOnly);
      expect(
        catalog.titleById('st')!.platforms.single.status,
        DistributionStatus.removed,
      );
    },
  );

  test('Prime Video aliases do not create duplicate Amazon platforms', () {
    final catalog = catalogWith([
      emptyTitle(platforms: [PlatformStatus.waiting('Amazon')]),
    ]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(
        platforms: [
          listing('Prime Video', providerId: '9'),
          listing('Amazon Prime Video', providerId: '119'),
          listing('Amazon Prime Video with Ads', providerId: '10'),
        ],
      ),
    );
    expect(catalog.titleById('st')!.platforms, hasLength(1));
    expect(catalog.titleById('st')!.platforms.single.platformName, 'Amazon');
    expect(
      catalog.titleById('st')!.platforms.single.status,
      DistributionStatus.live,
    );
  });

  test('manual Plex plus automatic PLEX merges into one MANUAL LIVE row', () {
    final catalog = catalogWith([
      emptyTitle(platforms: [PlatformStatus.waiting('Plex')]),
    ]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(platforms: [listing('PLEX', providerId: '209')]),
    );
    final platforms = catalog.titleById('st')!.platforms;
    expect(platforms, hasLength(1));
    expect(platforms.single.platformName, 'Plex');
    expect(platforms.single.origin, PlatformOrigin.manual);
    expect(
      platforms.single.licenseRelationship,
      LicenseRelationship.confirmedByUser,
    );
    expect(platforms.single.status, DistributionStatus.live);
    expect(platforms.single.firstDetectedAt, checkedAt);
    expect(platforms.single.lastMonitoringSource, 'TMDb Watch Providers');
    expect(platforms.single.history, hasLength(1));
  });

  test('discovered platform receives first-live, source, and history', () {
    final catalog = catalogWith([emptyTitle()]);
    catalog.applyDiscovery(
      'st',
      verifiedDiscovery(platforms: [listing('Plex')]),
    );
    final platform = catalog.titleById('st')!.platforms.single;
    expect(platform.firstDetectedAt, checkedAt);
    expect(platform.lastMonitoringSource, 'TMDb Watch Providers');
    expect(platform.history, hasLength(1));
    expect(platform.history.single.previousStatus, DistributionStatus.waiting);
    expect(platform.history.single.newStatus, DistributionStatus.live);
  });

  test('repeated discovery does not duplicate platform or history', () {
    final catalog = catalogWith([emptyTitle()]);
    final discovery = verifiedDiscovery(platforms: [listing('Plex')]);
    catalog.applyDiscovery('st', discovery);
    catalog.applyDiscovery('st', discovery);
    final title = catalog.titleById('st')!;
    expect(title.platforms, hasLength(1));
    expect(title.platforms.single.history, hasLength(1));
  });

  test('Check Status discovers platforms and persists external IDs', () async {
    final catalog = catalogWith([emptyTitle()]);
    await catalog.checkTitle(
      'st',
      _ScriptedDiscoveryMonitor(
        discovery: verifiedDiscovery(
          platforms: [listing('Netflix'), listing('Plex')],
        ),
      ),
    );
    final title = catalog.titleById('st')!;
    expect(title.tmdbId, '66732');
    expect(title.imdbId, 'tt4574334');
    expect(title.platforms.map((platform) => platform.platformName), [
      'Netflix',
      'Plex',
    ]);
    expect(catalog.lastCheckFeedback!.newlyDiscoveredNames, [
      'Netflix',
      'Plex',
    ]);
  });

  test('Check Status adds TMDb channels that were not already on the title', () async {
    final catalog = catalogWith([
      emptyTitle(
        platforms: [
          PlatformStatus.waiting('Relay'),
          PlatformStatus.waiting('Netflix'),
        ],
      ),
    ]);
    await catalog.checkTitle(
      'st',
      _ScriptedDiscoveryMonitor(
        discovery: verifiedDiscovery(
          platforms: [
            listing('Netflix'),
            listing('Plex'),
            listing('Tubi', providerId: '73'),
          ],
        ),
      ),
    );
    final title = catalog.titleById('st')!;
    expect(
      title.platforms.map((platform) => platform.platformName),
      containsAll(<String>['Relay', 'Netflix', 'Plex', 'Tubi']),
    );
    expect(title.platforms, hasLength(4));
    expect(
      title.platforms.firstWhere((platform) => platform.platformName == 'Relay').status,
      DistributionStatus.waiting,
    );
    expect(
      title.platforms
          .where((platform) => platform.status == DistributionStatus.live)
          .map((platform) => platform.platformName),
      containsAll(<String>['Netflix', 'Plex', 'Tubi']),
    );
    expect(catalog.lastCheckFeedback!.newlyDiscoveredNames, ['Plex', 'Tubi']);
    expect(catalog.lastCheckFeedback!.lookedUpPublicListings, isTrue);
  });

  test('Check All discovers platforms for every title', () async {
    final catalog = catalogWith([
      emptyTitle(),
      emptyTitle(id: 'marked', name: 'MARKED'),
    ]);
    await catalog.checkAllTitles(
      _ScriptedDiscoveryMonitor(
        discoveryByTitle: {
          'Stranger Things': verifiedDiscovery(
            platforms: [listing('Netflix')],
          ),
          'MARKED': verifiedDiscovery(
            tmdbId: '111',
            platforms: [listing('Plex')],
          ),
        },
      ),
    );
    expect(catalog.titleById('st')!.platforms.single.platformName, 'Netflix');
    expect(catalog.titleById('marked')!.platforms.single.platformName, 'Plex');
    expect(catalog.checkProgress!.newlyDiscoveredNames, ['Netflix', 'Plex']);
  });

  test('one discovery source failure does not abort other processing', () async {
    final catalog = catalogWith([
      emptyTitle(platforms: [PlatformStatus.waiting('Netflix')]),
      emptyTitle(id: 'marked', name: 'MARKED'),
    ]);
    await catalog.checkAllTitles(
      CompositeAvailabilityMonitor([
        _ScriptedDiscoveryMonitor(
          discoveryByTitle: {
            'Stranger Things': DiscoveryResult.failed(
              sourceName: 'Broken source',
              detail: 'unavailable',
              checkedAt: checkedAt,
            ),
            'MARKED': verifiedDiscovery(platforms: [listing('Plex')]),
          },
          liveOnCheck: {'Stranger Things'},
        ),
      ]),
    );
    expect(
      catalog.titleById('st')!.platforms.single.status,
      DistributionStatus.live,
    );
    expect(catalog.titleById('marked')!.platforms.single.platformName, 'Plex');
  });

  test('API error cannot create a discovered platform', () async {
    final catalog = catalogWith([emptyTitle()]);
    await catalog.checkTitle(
      'st',
      _ScriptedDiscoveryMonitor(
        discovery: DiscoveryResult.failed(
          sourceName: 'TMDb Watch Providers',
          detail: 'Availability source returned an error.',
          checkedAt: checkedAt,
        ),
      ),
    );
    expect(catalog.titleById('st')!.platforms, isEmpty);
  });

  test('ambiguous identity cannot create a discovered platform', () async {
    final catalog = catalogWith([emptyTitle()]);
    await catalog.checkTitle(
      'st',
      _ScriptedDiscoveryMonitor(
        discovery: DiscoveryResult.unverified(
          matchConfidence: MatchConfidence.possibleMatch,
          sourceName: 'TMDb Watch Providers',
          checkedAt: checkedAt,
        ),
      ),
    );
    expect(catalog.titleById('st')!.platforms, isEmpty);
  });

  test('title-only identity cannot create a discovered platform', () {
    final catalog = catalogWith([emptyTitle()]);
    catalog.applyDiscovery(
      'st',
      DiscoveryResult(
        matchConfidence: MatchConfidence.possibleMatch,
        sourceName: 'TMDb Watch Providers',
        checkedAt: checkedAt,
        platforms: [listing('Netflix')],
      ),
    );
    expect(catalog.titleById('st')!.platforms, isEmpty);
    expect(catalog.titleById('st')!.tmdbId, isNull);
  });

  test('failed discovery cannot create REMOVED', () async {
    final live = applyMonitoringResult(
      PlatformStatus.waiting('Netflix'),
      MonitoringResult.verifiedLive(
        platformName: 'Netflix',
        checkedAt: checkedAt,
        evidenceSource: 'TMDb Watch Providers',
      ),
    );
    final catalog = catalogWith([emptyTitle(platforms: [live])]);
    await catalog.checkTitle(
      'st',
      _ScriptedDiscoveryMonitor(
        discovery: DiscoveryResult.failed(
          sourceName: 'TMDb Watch Providers',
          detail: 'Could not reach the availability source.',
          checkedAt: checkedAt,
        ),
      ),
    );
    expect(
      catalog.titleById('st')!.platforms.single.status,
      DistributionStatus.live,
    );
    expect(catalog.titleById('st')!.platforms.single.lastCheckFailed, isTrue);
  });

  test('existing 3-absence removal safety still works with discovery', () {
    final live = applyMonitoringResult(
      PlatformStatus.waiting('Netflix'),
      MonitoringResult.verifiedLive(
        platformName: 'Netflix',
        checkedAt: checkedAt,
        evidenceSource: 'TMDb Watch Providers',
      ),
    );
    final catalog = catalogWith([emptyTitle(platforms: [live])]);
    final absent = verifiedDiscovery(platforms: const []);
    catalog.applyDiscovery('st', absent);
    catalog.applyDiscovery('st', absent);
    expect(
      catalog.titleById('st')!.platforms.single.status,
      DistributionStatus.live,
    );
    catalog.applyDiscovery('st', absent);
    expect(
      catalog.titleById('st')!.platforms.single.status,
      DistributionStatus.removed,
    );
  });

  test('external ID is persisted after verified identity resolution', () {
    final catalog = catalogWith([emptyTitle()]);
    catalog.applyDiscovery('st', verifiedDiscovery(platforms: const []));
    expect(catalog.titleById('st')!.tmdbId, '66732');
    expect(catalog.titleById('st')!.imdbId, 'tt4574334');
  });

  test('unknown provider survives persistence and restart', () async {
    final first = catalogWith([emptyTitle()], store: MemoryCatalogStore());
    first.applyDiscovery(
      'st',
      verifiedDiscovery(
        platforms: [listing('Some New Streaming Channel', providerId: '9001')],
      ),
    );
    await first.persistCompleted;

    final loaded = decodeCatalogSnapshot(
      encodeCatalogSnapshot(first.snapshot),
      existedOnDisk: true,
    );
    final platform = loaded.titles.single.platforms.single;
    expect(platform.platformName, 'Some New Streaming Channel');
    expect(platform.sourceProviderId, '9001');
    expect(platform.origin, PlatformOrigin.automatic);
    expect(platform.status, DistributionStatus.live);
  });

  test('dashboard attention groups discovered channels by title', () {
    final now = DateTime(2026, 9, 14);
    final attention = catalogAttention([
      emptyTitle(
        id: 'marked',
        name: 'MARKED',
        lastLookedUpAt: now,
        platforms: [
          PlatformStatus(
            platformName: 'Plex',
            status: DistributionStatus.live,
            origin: PlatformOrigin.automatic,
            licenseRelationship: LicenseRelationship.unknown,
            lastCheckedAt: now,
          ),
          PlatformStatus(
            platformName: 'Prime Video',
            status: DistributionStatus.live,
            lastCheckedAt: now,
          ),
          PlatformStatus(
            platformName: 'Relay',
            status: DistributionStatus.removed,
            lastCheckedAt: now,
          ),
        ],
      ),
    ]);

    expect(attention.discoveredByTitle.single.summary, 'MARKED is on 3 platforms.');
  });
}

class _ScriptedDiscoveryMonitor
    implements AvailabilityMonitor, DiscoveryMonitor {
  _ScriptedDiscoveryMonitor({
    this.discovery,
    this.discoveryByTitle = const {},
    this.liveOnCheck = const {},
  });

  final DiscoveryResult? discovery;
  final Map<String, DiscoveryResult> discoveryByTitle;
  final Set<String> liveOnCheck;

  @override
  String get sourceId => 'test-discovery';

  @override
  String get displayName => 'Test discovery';

  @override
  bool get isConfigured => true;

  @override
  Future<DiscoveryResult> discover({required TitleIdentity title}) async {
    return discovery ??
        discoveryByTitle[title.title] ??
        DiscoveryResult.unconfigured();
  }

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    if (liveOnCheck.contains(title.title)) {
      return MonitoringResult.verifiedLive(
        platformName: licensedPlatform,
        checkedAt: DateTime(2026, 9, 14, 18),
        evidenceSource: displayName,
      );
    }
    return MonitoringResult.failed(
      platformName: licensedPlatform,
      checkedAt: DateTime(2026, 9, 14, 18),
      detail: 'Could not complete this check',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/discovered_listings.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/tmdb_availability_monitor.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_store.dart';

import 'package:release_status/widgets/title_artwork.dart';

void main() {
  test('poster URL is built from TMDb poster_path without saving a file', () {
    expect(
      tmdbPosterUrl('/abc.jpg'),
      'https://image.tmdb.org/t/p/w500/abc.jpg',
    );
    expect(tmdbPosterUrl('abc.jpg'), 'https://image.tmdb.org/t/p/w500/abc.jpg');
    expect(tmdbPosterUrl(''), isNull);
    expect(tmdbPosterUrl(null), isNull);
  });

  testWidgets('artwork uses TMDb poster 2:3 dimensions, not a square', (
    tester,
  ) async {
    const title = ReleaseTitle(
      id: 'st',
      name: 'Stranger Things',
      releaseYear: 2016,
      contentType: 'TV Series',
      placeholderColor: Color(0xFF3A4A63),
      platforms: [],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TitleArtwork(title: title, size: 60)),
      ),
    );

    final box = tester.getSize(find.byType(TitleArtwork));
    expect(box.width, 60);
    expect(box.height, 90);
    expect(box.width / box.height, tmdbPosterAspectRatio);
  });

  test(
    'verified TMDb match returns poster and extra public listings',
    () async {
      final monitor = TmdbAvailabilityMonitor(
        apiKey: 'test-key',
        getJson: (path, query) async {
          if (path == '/3/search/tv') {
            return {
              'results': [
                {
                  'name': 'Stranger Things',
                  'first_air_date': '2016-07-15',
                  'id': 66732,
                  'poster_path': '/st.jpg',
                },
              ],
            };
          }
          if (path == '/3/tv/66732/watch/providers') {
            return {
              'results': {
                'US': {
                  'link': 'https://example.invalid/st',
                  'flatrate': [
                    {'provider_name': 'Netflix'},
                    {'provider_name': 'Hulu'},
                    {'provider_name': 'Prime Video'},
                  ],
                },
              },
            };
          }
          fail('Unexpected path $path');
        },
      );

      final result = await monitor.check(
        title: const TitleIdentity(
          title: 'Stranger Things',
          contentType: 'TV Series',
          releaseYear: 2016,
        ),
        licensedPlatform: 'Netflix',
      );

      expect(result.isVerifiedLive, isTrue);
      expect(result.posterUrl, 'https://image.tmdb.org/t/p/w500/st.jpg');
      expect(result.matchedTmdbId, '66732');
      expect(
        result.discoveredPlatforms.map((listing) => listing.providerName),
        containsAll(['Netflix', 'Hulu', 'Prime Video']),
      );
    },
  );

  test('licensed aliases are not treated as missed listings', () {
    final missing = listingsMissingFromLicensed(
      listings: const [
        DiscoveredPlatform(
          providerName: 'Netflix',
          sourceName: 'TMDb Watch Providers',
        ),
        DiscoveredPlatform(
          providerName: 'Amazon Prime Video',
          sourceName: 'TMDb Watch Providers',
        ),
        DiscoveredPlatform(
          providerName: 'Hulu',
          sourceName: 'TMDb Watch Providers',
        ),
      ],
      licensedPlatformNames: const ['Netflix', 'Amazon'],
    );

    expect(missing.map((listing) => listing.providerName), ['Hulu']);
  });

  test('adding a discovered listing populates a licensed LIVE platform', () {
    final catalog = TitleCatalog(
      initialTitles: const [
        ReleaseTitle(
          id: 'st',
          name: 'Stranger Things',
          releaseYear: 2016,
          contentType: 'TV Series',
          placeholderColor: Color(0xFF3A4A63),
          platforms: [PlatformStatus.waiting('Netflix')],
          discoveredPlatforms: [
            DiscoveredPlatform(
              providerName: 'Hulu',
              sourceName: 'TMDb Watch Providers',
              listingUrl: 'https://example.invalid/st',
            ),
          ],
        ),
      ],
    );

    catalog.addDiscoveredPlatforms('st', [
      catalog.titleById('st')!.discoveredPlatforms.single,
    ], checkedAt: DateTime(2026, 9, 14, 18));

    final title = catalog.titleById('st')!;
    expect(title.platforms, hasLength(2));
    expect(title.platforms.last.platformName, 'Hulu');
    expect(title.platforms.last.status, DistributionStatus.live);
    expect(title.platforms.last.origin, PlatformOrigin.automatic);
    expect(
      title.platforms.last.licenseRelationship,
      LicenseRelationship.unknown,
    );
    expect(title.discoveredPlatforms, isEmpty);
  });

  test('poster URL and missed listings persist', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    first.replaceAllTitles([
      const ReleaseTitle(
        id: 'st',
        name: 'Stranger Things',
        releaseYear: 2016,
        contentType: 'TV Series',
        placeholderColor: Color(0xFF3A4A63),
        posterUrl: 'https://image.tmdb.org/t/p/w500/st.jpg',
        tmdbId: '66732',
        platforms: [PlatformStatus.waiting('Netflix')],
        discoveredPlatforms: [
          DiscoveredPlatform(
            providerName: 'Hulu',
            sourceName: 'TMDb Watch Providers',
          ),
        ],
      ),
    ]);
    await first.persistCompleted;

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(
      second.titles.single.posterUrl,
      'https://image.tmdb.org/t/p/w500/st.jpg',
    );
    expect(
      second.titles.single.discoveredPlatforms.single.providerName,
      'Hulu',
    );
  });
}

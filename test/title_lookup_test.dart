import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/composite_monitor.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_lookup.dart';
import 'package:release_status/monitoring/tmdb_availability_monitor.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  test('TMDb name search returns movie and TV matches without a year', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        expect(query['query'], 'Stranger Things');
        if (query.containsKey('year') ||
            query.containsKey('first_air_date_year')) {
          return {'results': []};
        }
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
        if (path == '/3/search/movie') {
          return {
            'results': [
              {
                'title': 'Stranger Things',
                'release_date': '2017-01-01',
                'id': 99,
              },
            ],
          };
        }
        fail('unexpected path $path');
      },
    );

    final matches = await monitor.searchByName(name: 'Stranger Things');
    expect(matches, hasLength(2));
    expect(
      matches.map((match) => match.contentType),
      containsAll(<String>['TV Series', 'Movie']),
    );
    final tv = matches.firstWhere((match) => match.contentType == 'TV Series');
    expect(tv.name, 'Stranger Things');
    expect(tv.year, 2016);
    expect(tv.tmdbId, '66732');
    expect(
      matches.firstWhere((match) => match.contentType == 'Movie').year,
      2017,
    );
  });

  test('a TMDb TV page URL looks up MARKED by id', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        expect(path, '/3/tv/335294');
        return {
          'name': 'Marked',
          'first_air_date': '2026-09-02',
          'id': 335294,
          'poster_path': '/marked.jpg',
        };
      },
    );

    final matches = await monitor.searchByName(
      name: 'https://www.themoviedb.org/tv/335294-marked?language=en-US',
    );
    expect(matches, hasLength(1));
    expect(matches.single.name, 'Marked');
    expect(matches.single.contentType, 'TV Series');
    expect(matches.single.year, 2026);
    expect(matches.single.tmdbId, '335294');
  });

  test('search/tv can return a new low-profile title like MARKED', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        if (path == '/3/search/tv') {
          return {
            'results': [
              {
                'name': 'Marked',
                'first_air_date': '2026-09-02',
                'id': 335294,
              },
            ],
          };
        }
        if (path == '/3/search/movie') {
          return {'results': []};
        }
        fail('unexpected path $path');
      },
    );

    final matches = await monitor.searchByName(name: 'MARKED');
    expect(matches, hasLength(1));
    expect(matches.single.tmdbId, '335294');
    expect(matches.single.year, 2026);
  });

  test('a new Marked TV series still appears when TMDb ranks it on page 2', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        if (path == '/3/search/movie') {
          return {'results': []};
        }
        if (path != '/3/search/tv') {
          fail('unexpected path $path');
        }
        final page = query['page'] ?? '1';
        if (page == '1') {
          return {
            'page': 1,
            'total_pages': 2,
            'results': [
              for (var i = 1; i <= 20; i++)
                {
                  'name': 'Marked',
                  'first_air_date': '2010-01-01',
                  'id': i,
                },
            ],
          };
        }
        expect(page, '2');
        return {
          'page': 2,
          'total_pages': 2,
          'results': [
            {
              'name': 'Marked',
              'first_air_date': '2026-09-02',
              'id': 335294,
            },
          ],
        };
      },
    );

    final matches = await monitor.searchByName(name: 'Marked');
    expect(matches.first.tmdbId, '335294');
    expect(matches.first.year, 2026);
    expect(matches.map((match) => match.tmdbId), contains('335294'));
  });

  test('newest exact name is kept when more than 12 Marked titles exist', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        if (path == '/3/search/movie') {
          return {'results': []};
        }
        if (path != '/3/search/tv') {
          fail('unexpected path $path');
        }
        return {
          'results': [
            for (var year = 2010; year <= 2025; year++)
              {
                'name': 'Marked',
                'first_air_date': '$year-01-01',
                'id': year,
              },
            {
              'name': 'Marked',
              'first_air_date': '2026-09-02',
              'id': 335294,
            },
          ],
        };
      },
    );

    final matches = await monitor.searchByName(name: 'Marked');
    expect(matches.length, lessThanOrEqualTo(16));
    expect(matches.first.tmdbId, '335294');
    expect(matches.first.year, 2026);
  });

  test('year-scoped TV search surfaces a new Marked series movies would bury', () async {
    final boostYear = DateTime.now().year;
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        if (path == '/3/search/movie') {
          if (query.containsKey('year')) {
            return {'results': []};
          }
          return {
            'results': [
              for (var i = 1; i <= 20; i++)
                {
                  'title': 'Marked',
                  'release_date': '$boostYear-01-01',
                  'id': 9000 + i,
                },
            ],
          };
        }
        if (path != '/3/search/tv') {
          fail('unexpected path $path');
        }
        if (query['first_air_date_year'] == '$boostYear' ||
            query['year'] == '$boostYear') {
          return {
            'results': [
              {
                'name': 'Marked',
                'first_air_date': '$boostYear-09-02',
                'id': 335294,
              },
            ],
          };
        }
        if (query.containsKey('year') ||
            query.containsKey('first_air_date_year')) {
          return {'results': []};
        }
        return {
          'results': [
            {
              'name': 'Marked',
              'first_air_date': '2025-07-31',
              'id': 111,
            },
          ],
        };
      },
    );

    final matches = await monitor.searchByName(name: 'Marked');
    expect(
      matches.map((match) => match.tmdbId),
      contains('335294'),
    );
    expect(matches.first.tmdbId, '335294');
    expect(matches.first.contentType, 'TV Series');
    expect(matches.first.year, boostYear);
  });

  test('composite lookup uses the first configured title lookup', () async {
    final composite = CompositeAvailabilityMonitor([
      const UnconfiguredAvailabilityMonitor(),
      TmdbAvailabilityMonitor(
        apiKey: 'test-key',
        getJson: (path, query) async {
          if (path == '/3/search/movie') {
            return {
              'results': [
                {
                  'title': 'Harbor Light',
                  'release_date': '2024-03-01',
                  'id': 12,
                },
              ],
            };
          }
          return {'results': []};
        },
      ),
    ]);

    final matches = await composite.searchByName(name: 'Harbor Light');
    expect(matches, hasLength(1));
    expect(matches.single.year, 2024);
    expect(matches.single.tmdbId, '12');
  });

  test('parses a TMDb TV URL into an id', () {
    final reference = parseTmdbTitleReference(
      'https://www.themoviedb.org/tv/335294-marked?language=en-US',
    );
    expect(reference, isNotNull);
    expect(reference!.id, '335294');
    expect(reference.mediaType, 'tv');
  });

  test('unconfigured lookup returns no matches', () async {
    final monitor = TmdbAvailabilityMonitor(apiKey: '');
    expect(await monitor.searchByName(name: 'MARKED'), isEmpty);
  });

  testWidgets('selecting a lookup match fills type, year, and TMDb ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ReleaseStatusApp(
        availabilityMonitor: _FakeTitleLookup(),
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
      'Stranger Things',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('find-title-matches-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('title-match-dropdown')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('title-match-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Stranger Things  ·  TV Series  ·  2016').last,
    );
    await tester.pumpAndSettle();

    expect(find.text('2016'), findsWidgets);
    final catalog = TitleCatalogScope.of(
      tester.element(find.byKey(const ValueKey<String>('save-title-button'))),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-title-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
    await tester.pumpAndSettle();

    final title = catalog.titles.single;
    expect(title.name, 'Stranger Things');
    expect(title.contentType, 'TV Series');
    expect(title.releaseYear, 2016);
    expect(title.tmdbId, '66732');
    expect(title.posterUrl, 'https://image.tmdb.org/t/p/w500/st.jpg');
    expect(title.platforms, isEmpty);
  });
}

class _FakeTitleLookup implements AvailabilityMonitor, TitleLookup {
  @override
  bool get isConfigured => true;

  @override
  String get sourceId => 'test-lookup';

  @override
  String get displayName => 'Test lookup';

  @override
  Future<List<TitleLookupMatch>> searchByName({
    required String name,
    String? contentType,
    int? year,
  }) async {
    return const [
      TitleLookupMatch(
        name: 'Stranger Things',
        contentType: 'TV Series',
        year: 2016,
        tmdbId: '66732',
        posterUrl: 'https://image.tmdb.org/t/p/w500/st.jpg',
      ),
      TitleLookupMatch(
        name: 'Stranger Things',
        contentType: 'Movie',
        year: 2017,
        tmdbId: '99',
      ),
    ];
  }

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    return MonitoringResult.unconfigured(licensedPlatform);
  }
}

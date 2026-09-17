import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/production_monitor.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/tmdb_availability_monitor.dart';

void main() {
  const strangerThings = TitleIdentity(
    title: 'Stranger Things',
    contentType: 'TV Series',
    releaseYear: 2016,
  );

  test('absent TMDb key does not configure production monitoring', () {
    final monitor = createProductionAvailabilityMonitor();
    expect(monitor.isConfigured, isFalse);
  });

  test('empty TMDb key does not look up', () async {
    final monitor = TmdbAvailabilityMonitor(apiKey: '');
    expect(monitor.isConfigured, isFalse);
    final result = await monitor.check(
      title: strangerThings,
      licensedPlatform: 'Netflix',
    );
    expect(result.checkFailed, isFalse);
    expect(result.status, DistributionStatus.waiting);
    expect(result.kind, MonitoringResultKind.unconfigured);
  });

  test('verified TMDb listing can mark Netflix live', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        expect(query['api_key'], 'test-key');
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
                ],
              },
            },
          };
        }
        fail('Unexpected path $path');
      },
    );

    final result = await monitor.check(
      title: strangerThings,
      licensedPlatform: 'Netflix',
    );
    expect(result.isVerifiedLive, isTrue);
    expect(result.status, DistributionStatus.live);
    expect(result.evidenceSource, 'TMDb Watch Providers');
    expect(result.posterUrl, 'https://image.tmdb.org/t/p/w500/st.jpg');
  });

  test('ambiguous TMDb results stay possible matches', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        if (path == '/3/search/tv') {
          return {
            'results': [
              {'name': 'MARKED', 'first_air_date': '2026-01-01', 'id': 1},
              {'name': 'MARKED', 'first_air_date': '2026-06-01', 'id': 2},
            ],
          };
        }
        fail('Should not ask for watch providers');
      },
    );

    final result = await monitor.check(
      title: const TitleIdentity(
        title: 'MARKED',
        contentType: 'TV Series',
        releaseYear: 2026,
      ),
      licensedPlatform: 'Relay',
    );
    expect(result.matchConfidence, MatchConfidence.possibleMatch);
    expect(result.isVerifiedLive, isFalse);
    expect(result.status, DistributionStatus.waiting);
  });

  test('network failure is a failed check, not REMOVED', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        throw const SocketException('unavailable');
      },
    );

    final result = await monitor.check(
      title: strangerThings,
      licensedPlatform: 'Netflix',
    );
    expect(result.checkFailed, isTrue);
    expect(result.status, DistributionStatus.waiting);
    expect(result.detail, 'Could not reach the availability source.');
  });

  test('malformed provider response is a failed check', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        throw const FormatException(
          'Availability source returned invalid data.',
        );
      },
    );

    final result = await monitor.check(
      title: strangerThings,
      licensedPlatform: 'Netflix',
    );
    expect(result.checkFailed, isTrue);
    expect(result.detail, 'Availability source returned invalid data.');
  });

  test('authentication failure is a failed check', () async {
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        throw const HttpException(
          'The availability source rejected this request.',
        );
      },
    );

    final result = await monitor.check(
      title: strangerThings,
      licensedPlatform: 'Netflix',
    );
    expect(result.checkFailed, isTrue);
    expect(result.detail, 'The availability source rejected this request.');
  });

  test('discover returns every US provider including unknown names', () async {
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
        if (path == '/3/tv/66732/credits') {
          return {
            'crew': [
              {'name': 'The Duffer Brothers', 'job': 'Director'},
            ],
          };
        }
        if (path == '/3/tv/66732/external_ids') {
          return {'imdb_id': 'tt4574334'};
        }
        if (path == '/3/tv/66732/watch/providers') {
          return {
            'results': {
              'GB': {
                'flatrate': [
                  {'provider_name': 'BBC iPlayer', 'provider_id': 99},
                ],
              },
              'US': {
                'link': 'https://example.invalid/st',
                'flatrate': [
                  {'provider_name': 'Netflix', 'provider_id': 8},
                  {
                    'provider_name': 'Some New Streaming Channel',
                    'provider_id': 9001,
                  },
                ],
              },
            },
          };
        }
        fail('Unexpected path $path');
      },
    );

    final result = await monitor.discover(title: strangerThings);
    expect(result.isVerified, isTrue);
    expect(result.matchedTmdbId, '66732');
    expect(result.matchedImdbId, 'tt4574334');
    expect(
      result.platforms.map((listing) => listing.displayName),
      ['Netflix', 'Some New Streaming Channel'],
    );
    expect(
      result.platforms.map((listing) => listing.displayName),
      isNot(contains('BBC iPlayer')),
    );
  });

  test(
    'TV network is discovered when JustWatch has no US watch offers',
    () async {
      final monitor = TmdbAvailabilityMonitor(
        apiKey: 'test-key',
        getJson: (path, query) async {
          if (path == '/3/search/tv') {
            return {
              'results': [
                {
                  'name': 'Marked Military',
                  'first_air_date': '2021-01-06',
                  'id': 335317,
                },
              ],
            };
          }
          if (path == '/3/tv/335317/credits') {
            return {'crew': <Object>[]};
          }
          if (path == '/3/tv/335317/external_ids') {
            return <String, Object?>{};
          }
          if (path == '/3/tv/335317/watch/providers') {
            return {'results': <String, Object?>{}};
          }
          if (path == '/3/tv/335317') {
            return {
              'id': 335317,
              'name': 'Marked Military',
              'networks': [
                {'id': 7826, 'name': 'VET Tv'},
              ],
            };
          }
          fail('Unexpected path $path');
        },
      );

      final result = await monitor.discover(
        title: const TitleIdentity(
          title: 'Marked Military',
          contentType: 'TV Series',
          releaseYear: 2021,
        ),
      );
      expect(result.isVerified, isTrue);
      expect(result.platforms, hasLength(1));
      expect(result.platforms.single.displayName, 'VET Tv');
      expect(result.platforms.single.countsAsLiveEvidence, isFalse);
      expect(result.platforms.single.sourceName, 'TMDb Network');
    },
  );

  test('watch provider keeps live evidence when the same name is a network', () async {
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
              },
            ],
          };
        }
        if (path == '/3/tv/66732/credits') {
          return {'crew': <Object>[]};
        }
        if (path == '/3/tv/66732/external_ids') {
          return <String, Object?>{};
        }
        if (path == '/3/tv/66732/watch/providers') {
          return {
            'results': {
              'US': {
                'flatrate': [
                  {'provider_name': 'Netflix', 'provider_id': 8},
                ],
              },
            },
          };
        }
        if (path == '/3/tv/66732') {
          return {
            'networks': [
              {'id': 213, 'name': 'Netflix'},
            ],
          };
        }
        fail('Unexpected path $path');
      },
    );

    final result = await monitor.discover(title: strangerThings);
    expect(result.platforms, hasLength(1));
    expect(result.platforms.single.displayName, 'Netflix');
    expect(result.platforms.single.countsAsLiveEvidence, isTrue);
  });

  test('TMDb ID lookup is preferred over name search', () async {
    var searched = false;
    final monitor = TmdbAvailabilityMonitor(
      apiKey: 'test-key',
      getJson: (path, query) async {
        if (path == '/3/tv/66732') {
          return {
            'id': 66732,
            'name': 'Stranger Things',
            'first_air_date': '2016-07-15',
            'poster_path': '/st.jpg',
          };
        }
        if (path == '/3/tv/66732/watch/providers') {
          return {
            'results': {
              'US': {
                'flatrate': [
                  {'provider_name': 'Netflix'},
                ],
              },
            },
          };
        }
        if (path.contains('search')) {
          searched = true;
        }
        fail('Unexpected path $path');
      },
    );

    final result = await monitor.check(
      title: const TitleIdentity(
        title: 'Stranger Things',
        contentType: 'TV Series',
        releaseYear: 2016,
        tmdbId: '66732',
      ),
      licensedPlatform: 'Netflix',
    );
    expect(searched, isFalse);
    expect(result.isVerifiedLive, isTrue);
  });
}

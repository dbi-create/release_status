import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/platform_aliases.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_matcher.dart';

void main() {
  group('platform aliases', () {
    test('normalizes Amazon family names', () {
      expect(PlatformAliases.canonicalId('Amazon'), 'amazon');
      expect(PlatformAliases.canonicalId('Amazon Prime Video'), 'amazon');
      expect(PlatformAliases.canonicalId('Prime Video'), 'amazon');
      expect(
        PlatformAliases.referToSameService('Amazon', 'Prime Video'),
        isTrue,
      );
    });

    test('normalizes Plex, Fawesome, Ofive+, and Relay', () {
      expect(PlatformAliases.canonicalId('PLEX'), 'plex');
      expect(PlatformAliases.canonicalId('Plex'), 'plex');
      expect(PlatformAliases.canonicalId('Fawesome'), 'fawesome');
      expect(
        PlatformAliases.canonicalId('Future Today (Fawesome)'),
        'fawesome',
      );
      expect(PlatformAliases.canonicalId('Ofive+'), 'ofive_plus');
      expect(PlatformAliases.canonicalId('OFIVE+'), 'ofive_plus');
      expect(PlatformAliases.canonicalId('Relay'), 'relay');
      expect(PlatformAliases.canonicalId('Netflix'), 'netflix');
      expect(
        PlatformAliases.referToSameService(
          'Netflix',
          'Netflix Standard with Ads',
        ),
        isTrue,
      );
    });

    test('does not treat aliases as proof of availability', () {
      expect(PlatformAliases.referToSameService('Relay', 'Amazon'), isFalse);
    });

    test('merges a nickname with a TMDb listing when the URL is the same', () {
      expect(
        PlatformAliases.sameChannel(
          leftName: 'My Stream',
          leftUrl: 'https://watch.plex.tv/show/harbor-light',
          rightName: 'Plex',
          rightUrl: 'https://www.justwatch.com/us/tv-show/harbor-light',
        ),
        isTrue,
      );
      expect(
        PlatformAliases.sameChannel(
          leftName: 'Shopping Channel',
          leftUrl: 'https://www.amazon.com/gp/video/detail/foo',
          rightName: 'Amazon Prime Video',
          rightUrl: 'https://www.justwatch.com/us/movie/foo',
        ),
        isTrue,
      );
      expect(
        PlatformAliases.sameChannel(
          leftName: 'House Channel',
          leftUrl: 'https://stream.example.invalid/title/1',
          rightName: 'FooFlix',
          rightUrl: 'https://stream.example.invalid/title/1',
        ),
        isTrue,
      );
    });

    test('does not treat a shared JustWatch page as a unique channel', () {
      expect(
        PlatformAliases.sameChannel(
          leftName: 'Netflix',
          leftUrl: 'https://www.justwatch.com/us/tv-show/stranger-things',
          rightName: 'Hulu',
          rightUrl: 'https://www.justwatch.com/us/tv-show/stranger-things',
        ),
        isFalse,
      );
    });

    test('keeps a storefront URL instead of the shared JustWatch link', () {
      expect(
        PlatformAliases.preferSpecificListingUrl(
          'https://watch.plex.tv/show/harbor-light',
          'https://www.justwatch.com/us/tv-show/harbor-light',
        ),
        'https://watch.plex.tv/show/harbor-light',
      );
    });
  });

  group('title matching', () {
    const marked = TitleIdentity(
      title: 'MARKED',
      contentType: 'TV Series',
      releaseYear: 2026,
    );

    test('requires name, type, and year for a verified match', () {
      expect(
        classifyTitleMatch(
          query: marked,
          candidate: const TitleCandidate(
            name: 'MARKED',
            year: 2026,
            contentType: 'TV Series',
            externalId: '1',
          ),
        ),
        MatchConfidence.verifiedMatch,
      );
    });

    test('name-only match is not verified', () {
      expect(
        classifyTitleMatch(
          query: marked,
          candidate: const TitleCandidate(
            name: 'MARKED',
            year: 2011,
            contentType: 'TV Series',
          ),
        ),
        MatchConfidence.possibleMatch,
      );
    });

    test('wrong type is not a match', () {
      expect(
        classifyTitleMatch(
          query: marked,
          candidate: const TitleCandidate(
            name: 'MARKED',
            year: 2026,
            contentType: 'Movie',
          ),
        ),
        MatchConfidence.noMatch,
      );
    });

    test('credits can disambiguate identical name and year', () {
      expect(
        uniqueVerifiedCandidate(
          query: const TitleIdentity(
            title: 'MARKED',
            contentType: 'TV Series',
            releaseYear: 2026,
            director: 'Jane Director',
          ),
          candidates: const [
            TitleCandidate(
              name: 'MARKED',
              year: 2026,
              contentType: 'TV Series',
              externalId: '1',
              directors: ['Other Person'],
            ),
            TitleCandidate(
              name: 'MARKED',
              year: 2026,
              contentType: 'TV Series',
              externalId: '2',
              directors: ['Jane Director'],
            ),
          ],
        )?.externalId,
        '2',
      );
    });

    test('missing optional credits do not reject a valid match', () {
      expect(
        classifyTitleMatch(
          query: const TitleIdentity(
            title: 'MARKED',
            contentType: 'TV Series',
            releaseYear: 2026,
            director: 'Jane Director',
          ),
          candidate: const TitleCandidate(
            name: 'MARKED',
            year: 2026,
            contentType: 'TV Series',
            externalId: '1',
          ),
        ),
        MatchConfidence.verifiedMatch,
      );
    });

    test('conflicting director downgrades a name-year match', () {
      expect(
        classifyTitleMatch(
          query: const TitleIdentity(
            title: 'MARKED',
            contentType: 'TV Series',
            releaseYear: 2026,
            director: 'Jane Director',
          ),
          candidate: const TitleCandidate(
            name: 'MARKED',
            year: 2026,
            contentType: 'TV Series',
            directors: ['Someone Else'],
          ),
        ),
        MatchConfidence.possibleMatch,
      );
    });

    test('credits alone cannot verify a name-only candidate', () {
      expect(
        classifyTitleMatch(
          query: const TitleIdentity(
            title: 'MARKED',
            contentType: 'TV Series',
            releaseYear: 2026,
            director: 'Jane Director',
          ),
          candidate: const TitleCandidate(
            name: 'MARKED',
            year: 2011,
            contentType: 'TV Series',
            directors: ['Jane Director'],
          ),
        ),
        MatchConfidence.possibleMatch,
      );
    });

    test('ambiguous verified candidates become possible matches', () {
      expect(
        classifySearchResults(
          query: marked,
          candidates: const [
            TitleCandidate(
              name: 'MARKED',
              year: 2026,
              contentType: 'TV Series',
              externalId: '1',
            ),
            TitleCandidate(
              name: 'MARKED',
              year: 2026,
              contentType: 'TV Series',
              externalId: '2',
            ),
          ],
        ),
        MatchConfidence.possibleMatch,
      );
    });
  });

  group('applyMonitoringResult', () {
    test('verified live carries evidence and changes WAITING to LIVE', () {
      final updated = applyMonitoringResult(
        PlatformStatus.waiting('Relay'),
        MonitoringResult.verifiedLive(
          platformName: 'Relay',
          checkedAt: DateTime(2026, 9, 14, 18),
          evidenceSource: 'TMDb Watch Providers',
          evidenceUrl: 'https://example.invalid/relay/marked',
        ),
      );

      expect(updated.status, DistributionStatus.live);
      expect(updated.statusMessage, 'Detected on Relay');
      expect(updated.evidenceSource, 'TMDb Watch Providers');
      expect(updated.evidenceUrl, 'https://example.invalid/relay/marked');
      expect(updated.hasAvailabilityEvidence, isTrue);
    });

    test('failed checks keep WAITING', () {
      final updated = applyMonitoringResult(
        PlatformStatus.waiting('Amazon'),
        MonitoringResult.failed(
          platformName: 'Amazon',
          checkedAt: DateTime(2026, 9, 14, 18),
          detail: 'Could not reach the availability source.',
        ),
      );

      expect(updated.status, DistributionStatus.waiting);
      expect(updated.statusMessage, 'Could not complete this check');
      expect(updated.lastCheckFailed, isTrue);
    });

    test('unchecked platforms have no fake detection data', () {
      final platform = PlatformStatus.waiting('Relay');
      expect(platform.status, DistributionStatus.waiting);
      expect(platform.hasBeenDetected, isFalse);
      expect(platform.hasRealLookup, isFalse);
      expect(platform.evidenceSource, isNull);
      expect(platform.evidenceUrl, isNull);
      expect(platform.firstDetectedLabel, isNull);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/platform_aliases.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_matcher.dart';

/// Contacts The Movie Database watch-provider data when a key is supplied
/// via `--dart-define=TMDB_API_KEY=...`.
///
/// Does not fabricate matches. Unknown or ambiguous titles stay WAITING.
class TmdbAvailabilityMonitor implements AvailabilityMonitor {
  TmdbAvailabilityMonitor({
    required this.apiKey,
    this._httpClient,
    this.baseHost = 'api.themoviedb.org',
  });

  final String apiKey;
  final String baseHost;
  final HttpClient? _httpClient;

  static const evidenceSource = 'TMDb Watch Providers';

  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    if (!isConfigured) {
      return MonitoringResult.unconfigured(licensedPlatform);
    }

    final checkedAt = DateTime.now();
    try {
      final candidates = await _search(title);
      final confidence = classifySearchResults(
        query: title,
        candidates: candidates,
      );
      if (confidence == MatchConfidence.noMatch) {
        return MonitoringResult.notVerified(
          platformName: licensedPlatform,
          checkedAt: checkedAt,
          detail: 'No matching title was found in the availability source.',
        );
      }
      if (confidence == MatchConfidence.possibleMatch) {
        return MonitoringResult.notVerified(
          platformName: licensedPlatform,
          checkedAt: checkedAt,
          message: 'Possible match — verification required',
          matchConfidence: MatchConfidence.possibleMatch,
          detail:
              'A similar title was found, but identity was not unique enough to verify.',
        );
      }

      final match = uniqueVerifiedCandidate(
        query: title,
        candidates: candidates,
      );
      if (match == null || match.externalId == null) {
        return MonitoringResult.notVerified(
          platformName: licensedPlatform,
          checkedAt: checkedAt,
          message: 'Possible match — verification required',
          matchConfidence: MatchConfidence.possibleMatch,
        );
      }

      final providers = await _watchProviders(
        title.isTvSeries ? 'tv' : 'movie',
        match.externalId!,
      );
      final listing = _listingForPlatform(providers, licensedPlatform);
      if (listing == null) {
        return MonitoringResult.notVerified(
          platformName: licensedPlatform,
          checkedAt: checkedAt,
          detail:
              'Verified the title, but public availability was not listed for this platform.',
        );
      }

      return MonitoringResult.verifiedLive(
        platformName: licensedPlatform,
        checkedAt: checkedAt,
        evidenceSource: evidenceSource,
        evidenceUrl: listing.link,
        detail: 'Listed as ${listing.providerName}.',
      );
    } on Object catch (error) {
      return MonitoringResult.failed(
        platformName: licensedPlatform,
        checkedAt: checkedAt,
        detail: _safeErrorMessage(error),
      );
    }
  }

  Future<List<TitleCandidate>> _search(TitleIdentity title) async {
    final path = title.isTvSeries ? '/3/search/tv' : '/3/search/movie';
    final query = <String, String>{
      'api_key': apiKey,
      'query': title.title,
      'include_adult': 'false',
    };
    if (title.isTvSeries) {
      query['first_air_date_year'] = '${title.releaseYear}';
    } else {
      query['year'] = '${title.releaseYear}';
    }

    final data = await _getJson(path, query);
    final results = data['results'];
    if (results is! List) {
      return const [];
    }

    return [
      for (final raw in results)
        if (raw is Map<String, dynamic>)
          TitleCandidate(
            name: title.isTvSeries
                ? '${raw['name'] ?? raw['original_name'] ?? ''}'
                : '${raw['title'] ?? raw['original_title'] ?? ''}',
            year: _yearFromDate(
              title.isTvSeries
                  ? raw['first_air_date'] as String?
                  : raw['release_date'] as String?,
            ),
            contentType: title.contentType,
            externalId: raw['id']?.toString(),
          ),
    ];
  }

  Future<List<_ProviderListing>> _watchProviders(
    String mediaType,
    String tmdbId,
  ) async {
    final data = await _getJson('/3/$mediaType/$tmdbId/watch/providers', {
      'api_key': apiKey,
    });
    final results = data['results'];
    if (results is! Map<String, dynamic>) {
      return const [];
    }

    final listings = <_ProviderListing>[];
    for (final region in results.values) {
      if (region is! Map<String, dynamic>) {
        continue;
      }
      final link = region['link'] as String?;
      for (final bucket in const ['flatrate', 'free', 'ads', 'rent', 'buy']) {
        final entries = region[bucket];
        if (entries is! List) {
          continue;
        }
        for (final entry in entries) {
          if (entry is! Map<String, dynamic>) {
            continue;
          }
          final name = '${entry['provider_name'] ?? ''}'.trim();
          if (name.isEmpty) {
            continue;
          }
          listings.add(_ProviderListing(providerName: name, link: link));
        }
      }
    }
    return listings;
  }

  _ProviderListing? _listingForPlatform(
    List<_ProviderListing> listings,
    String licensedPlatform,
  ) {
    for (final listing in listings) {
      if (PlatformAliases.referToSameService(
        licensedPlatform,
        listing.providerName,
      )) {
        return listing;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(baseHost, path, query);
    final client = _httpClient ?? HttpClient();
    final createdClient = _httpClient == null;
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Availability source returned an error.');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Availability source returned invalid data.',
        );
      }
      return decoded;
    } finally {
      if (createdClient) {
        client.close(force: true);
      }
    }
  }

  int? _yearFromDate(String? value) {
    if (value == null || value.length < 4) {
      return null;
    }
    return int.tryParse(value.substring(0, 4));
  }

  String _safeErrorMessage(Object error) {
    if (error is SocketException) {
      return 'Could not reach the availability source.';
    }
    if (error is HttpException) {
      return 'Availability source returned an error.';
    }
    if (error is FormatException) {
      return 'Availability source returned invalid data.';
    }
    return 'The availability check did not complete.';
  }
}

class _ProviderListing {
  const _ProviderListing({required this.providerName, this.link});

  final String providerName;
  final String? link;
}

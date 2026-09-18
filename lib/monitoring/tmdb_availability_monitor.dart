import 'dart:convert';
import 'dart:io';

import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/discovered_listings.dart';
import 'package:release_status/monitoring/discovery_monitor.dart';
import 'package:release_status/monitoring/discovery_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/platform_aliases.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_lookup.dart';
import 'package:release_status/monitoring/title_matcher.dart';

typedef TmdbJsonGetter =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, String> query,
    );

/// Contacts The Movie Database watch-provider data when a key is supplied
/// via `--dart-define=TMDB_API_KEY=...`.
///
/// Does not fabricate matches. Unknown or ambiguous titles stay WAITING.
class TmdbAvailabilityMonitor
    implements AvailabilityMonitor, DiscoveryMonitor, TitleLookup {
  TmdbAvailabilityMonitor({
    required this.apiKey,
    this.baseHost = 'api.themoviedb.org',
    this.httpClient,
    this.getJson,
  });

  final String apiKey;
  final String baseHost;
  final HttpClient? httpClient;
  final TmdbJsonGetter? getJson;

  static const evidenceSource = 'TMDb Watch Providers';
  static const networkSource = 'TMDb Network';

  /// Region currently used by this app for watch-provider lookups.
  static const watchRegion = 'US';

  @override
  String get sourceId => 'tmdb';

  @override
  String get displayName => evidenceSource;

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
      final candidates = await _resolveCandidates(title);
      final confidence = classifySearchResults(
        query: title,
        candidates: candidates,
      );
      if (confidence == MatchConfidence.noMatch) {
        return MonitoringResult.notVerified(
          platformName: licensedPlatform,
          checkedAt: checkedAt,
          sourceName: displayName,
          detail: 'No matching title was found in the availability source.',
        );
      }
      if (confidence == MatchConfidence.possibleMatch) {
        return MonitoringResult.notVerified(
          platformName: licensedPlatform,
          checkedAt: checkedAt,
          sourceName: displayName,
          message: 'This title could not be confidently matched',
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
          sourceName: displayName,
          message: 'This title could not be confidently matched',
          matchConfidence: MatchConfidence.possibleMatch,
        );
      }

      final providers = await _watchProviders(
        title.isTvSeries ? 'tv' : 'movie',
        match.externalId!,
      );
      final discovered = [
        for (final listing in providers)
          DiscoveredPlatform(
            providerName: listing.providerName,
            sourceName: displayName,
            listingUrl: listing.link,
          ),
      ];
      final listing = _listingForPlatform(providers, licensedPlatform);
      final result = listing == null
          ? MonitoringResult.verifiedAbsence(
              platformName: licensedPlatform,
              checkedAt: checkedAt,
              evidenceSource: evidenceSource,
              sourceName: displayName,
              detail:
                  'Verified the title, but public availability was not listed for this platform.',
            )
          : MonitoringResult.verifiedLive(
              platformName: licensedPlatform,
              checkedAt: checkedAt,
              evidenceSource: evidenceSource,
              evidenceUrl: listing.link,
              sourceName: displayName,
              detail: 'Listed as ${listing.providerName}.',
            );
      return result.withTitleDiscovery(
        posterUrl: tmdbPosterUrl(match.posterPath),
        matchedTmdbId: match.externalId,
        discoveredPlatforms: discovered,
      );
    } on Object catch (error) {
      return MonitoringResult.failed(
        platformName: licensedPlatform,
        checkedAt: checkedAt,
        sourceName: displayName,
        detail: _safeErrorMessage(error),
      );
    }
  }

  @override
  Future<DiscoveryResult> discover({required TitleIdentity title}) async {
    if (!isConfigured) {
      return DiscoveryResult.unconfigured();
    }
    final checkedAt = DateTime.now();
    try {
      var candidates = await _resolveCandidates(title);
      var match = uniqueVerifiedCandidate(query: title, candidates: candidates);
      if (match == null) {
        final verifiedCount = candidates
            .where(
              (candidate) =>
                  classifyTitleMatch(query: title, candidate: candidate) ==
                  MatchConfidence.verifiedMatch,
            )
            .length;
        if (verifiedCount > 1) {
          candidates = await _attachCredits(title, candidates);
          match = uniqueVerifiedCandidate(
            query: title,
            candidates: candidates,
          );
        }
      }
      if (match == null || match.externalId == null) {
        final confidence = classifySearchResults(
          query: title,
          candidates: candidates,
        );
        return DiscoveryResult.unverified(
          matchConfidence: confidence == MatchConfidence.verifiedMatch
              ? MatchConfidence.possibleMatch
              : confidence,
          sourceName: displayName,
          checkedAt: checkedAt,
          detail: confidence == MatchConfidence.noMatch
              ? 'No matching title was found in the availability source.'
              : 'A similar title was found, but identity was not unique enough to verify.',
        );
      }

      final mediaType = title.isTvSeries ? 'tv' : 'movie';
      final credited = await _creditsFor(mediaType, match.externalId!);
      final providers = await _watchProviders(mediaType, match.externalId!);
      final networks = await _networksFor(mediaType, match.externalId!);
      return DiscoveryResult(
        matchConfidence: MatchConfidence.verifiedMatch,
        sourceName: displayName,
        checkedAt: checkedAt,
        matchedTmdbId: match.externalId,
        matchedImdbId: credited.imdbId ?? match.imdbId,
        posterUrl: tmdbPosterUrl(match.posterPath),
        director: credited.director,
        producer: credited.producer,
        writer: credited.writer,
        platforms: _uniqueDiscoveries(
          watchProviders: providers,
          networks: networks,
        ),
      );
    } on Object catch (error) {
      return DiscoveryResult.failed(
        sourceName: displayName,
        checkedAt: checkedAt,
        detail: _safeErrorMessage(error),
      );
    }
  }

  @override
  Future<List<TitleLookupMatch>> searchByName({
    required String name,
    String? contentType,
    int? year,
  }) async {
    if (!isConfigured) {
      return const [];
    }
    final query = name.trim();
    if (query.isEmpty) {
      return const [];
    }
    final matches = <TitleLookupMatch>[];
    final seen = <String>{};

    void addMatch(TitleLookupMatch? match) {
      if (match == null || seen.contains(match.id)) {
        return;
      }
      seen.add(match.id);
      matches.add(match);
    }

    try {
      final reference = parseTmdbTitleReference(query);
      if (reference != null) {
        for (final mediaType in reference.mediaTypes) {
          addMatch(await _lookupMatchById(mediaType, reference.id));
        }
        if (matches.isNotEmpty) {
          return matches;
        }
      }

      final type = contentType?.trim().toLowerCase();
      final searchTv = type != 'movie';
      final searchMovie = type != 'tv series';

      if (searchTv) {
        for (final raw in await _searchResults('/3/search/tv', query)) {
          addMatch(_lookupMatchFromSearch(raw, isTv: true));
        }
      }
      if (searchMovie) {
        for (final raw in await _searchResults('/3/search/movie', query)) {
          addMatch(_lookupMatchFromSearch(raw, isTv: false));
        }
      }

      // Popularity search buries new shows. A year-scoped pass finds titles
      // like MARKED (2026) even when they are not on the first pages.
      for (final boostYear in _yearsToBoost(year)) {
        if (searchTv) {
          for (final yearKey in const ['first_air_date_year', 'year']) {
            for (final raw in await _searchResults(
              '/3/search/tv',
              query,
              year: boostYear,
              yearQueryKey: yearKey,
              maxPages: 1,
            )) {
              addMatch(_lookupMatchFromSearch(raw, isTv: true));
            }
          }
        }
        if (searchMovie) {
          for (final raw in await _searchResults(
            '/3/search/movie',
            query,
            year: boostYear,
            yearQueryKey: 'year',
            maxPages: 1,
          )) {
            addMatch(_lookupMatchFromSearch(raw, isTv: false));
          }
        }
      }
    } on Object {
      if (matches.isEmpty) {
        return const [];
      }
    }
    return _sortedLookupMatches(
      matches,
      query: query,
      year: year,
      contentType: contentType,
    );
  }

  Set<int> _yearsToBoost(int? year) {
    final nowYear = DateTime.now().year;
    return {
      ?year,
      nowYear,
      nowYear + 1,
    };
  }

  Future<List<Map<String, dynamic>>> _searchResults(
    String path,
    String query, {
    int? year,
    String? yearQueryKey,
    int maxPages = 5,
  }) async {
    final collected = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final params = <String, String>{
        'api_key': apiKey,
        'query': query,
        'include_adult': 'false',
        'page': '$page',
      };
      if (year != null && yearQueryKey != null) {
        params[yearQueryKey] = '$year';
      }
      final data = await _getJson(path, params);
      final results = data['results'];
      if (results is List) {
        for (final raw in results) {
          if (raw is Map) {
            collected.add(Map<String, dynamic>.from(raw));
          }
        }
      }
      final totalPages = _intValue(data['total_pages']) ?? page;
      if (page >= totalPages) {
        break;
      }
    }
    return collected;
  }

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  Future<TitleLookupMatch?> _lookupMatchById(
    String mediaType,
    String id,
  ) async {
    try {
      final data = await _getJson('/3/$mediaType/$id', {'api_key': apiKey});
      return _lookupMatchFromSearch(data, isTv: mediaType == 'tv');
    } on Object {
      return null;
    }
  }

  TitleLookupMatch? _lookupMatchFromSearch(
    Map<String, dynamic> raw, {
    required bool isTv,
  }) {
    final name = isTv
        ? '${raw['name'] ?? raw['original_name'] ?? ''}'.trim()
        : '${raw['title'] ?? raw['original_title'] ?? ''}'.trim();
    if (name.isEmpty) {
      return null;
    }
    return TitleLookupMatch(
      name: name,
      contentType: isTv ? 'TV Series' : 'Movie',
      year: _yearFromDate(
        isTv
            ? raw['first_air_date'] ?? raw['release_date']
            : raw['release_date'] ?? raw['first_air_date'],
      ),
      tmdbId: raw['id']?.toString(),
      posterUrl: tmdbPosterUrl(raw['poster_path']?.toString()),
    );
  }

  List<TitleLookupMatch> _sortedLookupMatches(
    List<TitleLookupMatch> matches, {
    required String query,
    int? year,
    String? contentType,
  }) {
    final needle = normalizeTitleName(query);
    final preferredType = contentType?.trim().toLowerCase();
    final originalIndex = <String, int>{
      for (var i = 0; i < matches.length; i++) matches[i].id: i,
    };
    matches.sort((left, right) {
      final leftExact = normalizeTitleName(left.name) == needle;
      final rightExact = normalizeTitleName(right.name) == needle;
      if (leftExact != rightExact) {
        return leftExact ? -1 : 1;
      }
      if (year != null) {
        final leftYear = left.year == year;
        final rightYear = right.year == year;
        if (leftYear != rightYear) {
          return leftYear ? -1 : 1;
        }
      }
      final leftYearValue = left.year ?? -1;
      final rightYearValue = right.year ?? -1;
      if (leftYearValue != rightYearValue) {
        return rightYearValue.compareTo(leftYearValue);
      }
      if (preferredType != null && preferredType.isNotEmpty) {
        final leftType = left.contentType.toLowerCase() == preferredType;
        final rightType = right.contentType.toLowerCase() == preferredType;
        if (leftType != rightType) {
          return leftType ? -1 : 1;
        }
      } else {
        final leftTv = left.contentType == 'TV Series';
        final rightTv = right.contentType == 'TV Series';
        if (leftTv != rightTv) {
          return leftTv ? -1 : 1;
        }
      }
      return originalIndex[left.id]!.compareTo(originalIndex[right.id]!);
    });
    return _cappedLookupMatches(matches, query: query);
  }

  List<TitleLookupMatch> _cappedLookupMatches(
    List<TitleLookupMatch> matches, {
    required String query,
  }) {
    const cap = 16;
    if (matches.length <= cap) {
      return matches;
    }
    final needle = normalizeTitleName(query);
    final kept = <TitleLookupMatch>[];
    final seenTypeYear = <String>{};
    for (final match in matches) {
      if (normalizeTitleName(match.name) != needle) {
        continue;
      }
      final key = '${match.contentType}:${match.year}';
      if (!seenTypeYear.add(key)) {
        continue;
      }
      kept.add(match);
      if (kept.length >= cap) {
        return kept;
      }
    }
    for (final match in matches) {
      if (kept.contains(match)) {
        continue;
      }
      kept.add(match);
      if (kept.length >= cap) {
        break;
      }
    }
    return kept;
  }

  Future<List<TitleCandidate>> _resolveCandidates(TitleIdentity title) async {
    if (title.hasTmdbId) {
      final byId = await _lookupByTmdbId(title);
      if (byId != null) {
        return [byId];
      }
    }
    if (title.hasImdbId) {
      final byImdb = await _lookupByImdbId(title);
      if (byImdb.isNotEmpty) {
        return byImdb;
      }
    }
    return _search(title);
  }

  Future<TitleCandidate?> _lookupByTmdbId(TitleIdentity title) async {
    final mediaType = title.isTvSeries ? 'tv' : 'movie';
    final data = await _getJson('/3/$mediaType/${title.tmdbId!.trim()}', {
      'api_key': apiKey,
    });
    final name = title.isTvSeries
        ? '${data['name'] ?? data['original_name'] ?? ''}'
        : '${data['title'] ?? data['original_title'] ?? ''}';
    if (name.trim().isEmpty) {
      return null;
    }
    return TitleCandidate(
      name: name,
      year: _yearFromDate(
        title.isTvSeries ? data['first_air_date'] : data['release_date'],
      ),
      contentType: title.contentType,
      externalId: '${data['id'] ?? title.tmdbId}',
      posterPath: data['poster_path'] as String?,
    );
  }

  Future<List<TitleCandidate>> _lookupByImdbId(TitleIdentity title) async {
    final data = await _getJson('/3/find/${title.imdbId!.trim()}', {
      'api_key': apiKey,
      'external_source': 'imdb_id',
    });
    final key = title.isTvSeries ? 'tv_results' : 'movie_results';
    final results = data[key];
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
              title.isTvSeries ? raw['first_air_date'] : raw['release_date'],
            ),
            contentType: title.contentType,
            externalId: raw['id']?.toString(),
            posterPath: raw['poster_path'] as String?,
          ),
    ];
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

    var results = await _searchList(path, query);
    if (results.isEmpty) {
      query.remove('first_air_date_year');
      query.remove('year');
      results = await _searchList(path, query);
    }

    return [
      for (final raw in results)
        TitleCandidate(
          name: title.isTvSeries
              ? '${raw['name'] ?? raw['original_name'] ?? ''}'
              : '${raw['title'] ?? raw['original_title'] ?? ''}',
          year: _yearFromDate(
            title.isTvSeries ? raw['first_air_date'] : raw['release_date'],
          ),
          contentType: title.contentType,
          externalId: raw['id']?.toString(),
          posterPath: raw['poster_path'] as String?,
        ),
    ];
  }

  Future<List<Map<String, dynamic>>> _searchList(
    String path,
    Map<String, String> query,
  ) async {
    final data = await _getJson(path, query);
    final results = data['results'];
    if (results is! List) {
      return const [];
    }
    return [
      for (final raw in results)
        if (raw is Map) Map<String, dynamic>.from(raw),
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

    final region = results[watchRegion];
    if (region is! Map<String, dynamic>) {
      return const [];
    }

    final listings = <_ProviderListing>[];
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
        listings.add(
          _ProviderListing(
            providerName: name,
            link: link,
            providerId: entry['provider_id']?.toString(),
          ),
        );
      }
    }
    return listings;
  }

  /// Original TV network from TMDb series metadata. Not JustWatch availability.
  Future<List<_ProviderListing>> _networksFor(
    String mediaType,
    String tmdbId,
  ) async {
    if (mediaType != 'tv') {
      return const [];
    }
    try {
      final data = await _getJson('/3/tv/$tmdbId', {'api_key': apiKey});
      final networks = data['networks'];
      if (networks is! List) {
        return const [];
      }
      final listings = <_ProviderListing>[];
      for (final raw in networks) {
        if (raw is! Map) {
          continue;
        }
        final entry = Map<String, dynamic>.from(raw);
        final name = '${entry['name'] ?? ''}'.trim();
        if (name.isEmpty) {
          continue;
        }
        listings.add(_ProviderListing(providerName: name));
      }
      return listings;
    } on Object {
      return const [];
    }
  }

  _ProviderListing? _listingForPlatform(
    List<_ProviderListing> listings,
    String licensedPlatform,
  ) {
    for (final listing in listings) {
      if (PlatformAliases.sameChannel(
        leftName: licensedPlatform,
        rightName: listing.providerName,
        rightUrl: listing.link,
        rightProviderId: listing.providerId,
      )) {
        return listing;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) {
    final injected = getJson;
    if (injected != null) {
      return injected(path, query);
    }
    return _httpGetJson(path, query);
  }

  Future<Map<String, dynamic>> _httpGetJson(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.https(baseHost, path, query);
    final client = httpClient ?? HttpClient();
    final createdClient = httpClient == null;
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const HttpException(
          'The availability source rejected this request.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const HttpException('Availability source returned an error.');
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

  int? _yearFromDate(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.length < 4) {
      return null;
    }
    return int.tryParse(text.substring(0, 4));
  }

  String _safeErrorMessage(Object error) {
    if (error is SocketException) {
      return 'Could not reach the availability source.';
    }
    if (error is HttpException) {
      return error.message.isEmpty
          ? 'Availability source returned an error.'
          : error.message;
    }
    if (error is FormatException) {
      return 'Availability source returned invalid data.';
    }
    return 'The availability check did not complete.';
  }

  Future<List<TitleCandidate>> _attachCredits(
    TitleIdentity title,
    List<TitleCandidate> candidates,
  ) async {
    final mediaType = title.isTvSeries ? 'tv' : 'movie';
    final updated = <TitleCandidate>[];
    for (final candidate in candidates) {
      final id = candidate.externalId;
      if (id == null) {
        updated.add(candidate);
        continue;
      }
      final credits = await _creditsFor(mediaType, id);
      updated.add(
        candidate.copyWith(
          directors: credits.directors,
          producers: credits.producers,
          writers: credits.writers,
          imdbId: credits.imdbId,
        ),
      );
    }
    return updated;
  }

  Future<_TitleCredits> _creditsFor(String mediaType, String tmdbId) async {
    var directors = const <String>[];
    var producers = const <String>[];
    var writers = const <String>[];
    String? imdbId;
    try {
      final data = await _getJson('/3/$mediaType/$tmdbId/credits', {
        'api_key': apiKey,
      });
      final parsed = _parseCrew(data['crew']);
      directors = parsed.directors;
      producers = parsed.producers;
      writers = parsed.writers;
    } catch (_) {}
    try {
      final ids = await _getJson('/3/$mediaType/$tmdbId/external_ids', {
        'api_key': apiKey,
      });
      final value = ids['imdb_id'] as String?;
      if (value != null && value.trim().isNotEmpty) {
        imdbId = value.trim();
      }
    } catch (_) {}
    return _TitleCredits(
      directors: directors,
      producers: producers,
      writers: writers,
      imdbId: imdbId,
    );
  }

  _TitleCredits _parseCrew(Object? crew) {
    if (crew is! List) {
      return const _TitleCredits();
    }
    final directors = <String>[];
    final producers = <String>[];
    final writers = <String>[];
    for (final raw in crew) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final name = '${raw['name'] ?? ''}'.trim();
      final job = '${raw['job'] ?? ''}'.trim().toLowerCase();
      if (name.isEmpty || job.isEmpty) {
        continue;
      }
      if (job == 'director' && !directors.contains(name)) {
        directors.add(name);
      }
      if ((job == 'producer' || job == 'executive producer') &&
          !producers.contains(name)) {
        producers.add(name);
      }
      if ((job == 'writer' || job == 'screenplay' || job == 'teleplay') &&
          !writers.contains(name)) {
        writers.add(name);
      }
    }
    return _TitleCredits(
      directors: directors,
      producers: producers,
      writers: writers,
    );
  }

  List<DiscoveredAvailability> _uniqueDiscoveries({
    required List<_ProviderListing> watchProviders,
    List<_ProviderListing> networks = const [],
  }) {
    final seen = <String>{};
    final discovered = <DiscoveredAvailability>[];

    void add(_ProviderListing listing, {required bool liveEvidence}) {
      final key =
          PlatformAliases.canonicalId(listing.providerName) ??
          listing.providerId ??
          PlatformAliases.normalize(listing.providerName);
      if (seen.contains(key)) {
        return;
      }
      seen.add(key);
      discovered.add(
        DiscoveredAvailability(
          displayName: listing.providerName,
          sourceName: liveEvidence ? displayName : networkSource,
          sourceProviderId: liveEvidence ? listing.providerId : null,
          canonicalId: PlatformAliases.canonicalId(listing.providerName),
          listingUrl: liveEvidence ? listing.link : null,
          countsAsLiveEvidence: liveEvidence,
          detail: liveEvidence
              ? 'Listed as ${listing.providerName}.'
              : 'TMDb lists ${listing.providerName} as the original network. '
                  'This is not a current US watch offer.',
        ),
      );
    }

    for (final listing in watchProviders) {
      add(listing, liveEvidence: true);
    }
    for (final listing in networks) {
      add(listing, liveEvidence: false);
    }
    return discovered;
  }
}

class _TitleCredits {
  const _TitleCredits({
    this.directors = const [],
    this.producers = const [],
    this.writers = const [],
    this.imdbId,
  });

  final List<String> directors;
  final List<String> producers;
  final List<String> writers;
  final String? imdbId;

  String? get director => directors.isEmpty ? null : directors.first;
  String? get producer => producers.isEmpty ? null : producers.first;
  String? get writer => writers.isEmpty ? null : writers.first;
}

class _ProviderListing {
  const _ProviderListing({
    required this.providerName,
    this.link,
    this.providerId,
  });

  final String providerName;
  final String? link;
  final String? providerId;
}

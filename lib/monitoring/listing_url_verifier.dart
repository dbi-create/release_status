import 'dart:convert';
import 'dart:io';

import 'package:release_status/monitoring/title_identity.dart';

/// Result of checking a user-provided public listing URL.
///
/// This is not a TMDb watch-provider listing and does not scrape a catalog.
class ListingUrlCheckResult {
  const ListingUrlCheckResult._({
    required this.isVerifiedLive,
    this.errorMessage,
    this.normalizedUrl,
  });

  const ListingUrlCheckResult.verified({required String normalizedUrl})
    : this._(isVerifiedLive: true, normalizedUrl: normalizedUrl);

  const ListingUrlCheckResult.rejected(String errorMessage)
    : this._(isVerifiedLive: false, errorMessage: errorMessage);

  final bool isVerifiedLive;
  final String? errorMessage;
  final String? normalizedUrl;
}

typedef ListingUrlChecker =
    Future<ListingUrlCheckResult> Function({
      required String titleName,
      required String url,
    });

/// Accepts only public http(s) URLs with a host.
Uri? parseListingUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  return uri;
}

/// True when the title name appears in the listing URL or page text.
bool listingPageMentionsTitle({
  required String titleName,
  required String url,
  required String pageText,
}) {
  final needle = normalizeTitleName(titleName);
  if (needle.isEmpty) {
    return false;
  }
  return normalizeTitleName(url).contains(needle) ||
      normalizeTitleName(pageText).contains(needle);
}

ListingUrlCheckResult verifyFetchedListing({
  required String titleName,
  required Uri uri,
  required int statusCode,
  required String body,
}) {
  if (statusCode < 200 || statusCode >= 400) {
    if (statusCode == 404 || statusCode == 410) {
      return const ListingUrlCheckResult.rejected(
        'That listing page was not found. Check the live URL and try again.',
      );
    }
    return const ListingUrlCheckResult.rejected(
      'That listing page could not be opened. Check the live URL and try again.',
    );
  }
  if (!listingPageMentionsTitle(
    titleName: titleName,
    url: uri.toString(),
    pageText: body,
  )) {
    return const ListingUrlCheckResult.rejected(
      'The page is reachable, but this title name was not found on it. Use the public page for this exact show.',
    );
  }
  return ListingUrlCheckResult.verified(normalizedUrl: uri.toString());
}

/// Fetches a user-pasted listing URL and checks that it mentions the title.
Future<ListingUrlCheckResult> fetchAndVerifyListingUrl({
  required String titleName,
  required String url,
  HttpClient? httpClient,
}) async {
  final name = titleName.trim();
  if (name.isEmpty) {
    return const ListingUrlCheckResult.rejected(
      'Enter the title name first so the listing page can be checked.',
    );
  }
  final uri = parseListingUrl(url);
  if (uri == null) {
    return const ListingUrlCheckResult.rejected(
      'Enter a public http or https listing URL.',
    );
  }

  final client = httpClient ?? HttpClient();
  final createdClient = httpClient == null;
  try {
    client.connectionTimeout = const Duration(seconds: 15);
    final request = await client.getUrl(uri);
    request.followRedirects = true;
    request.maxRedirects = 5;
    request.headers.set(HttpHeaders.acceptHeader, 'text/html, */*;q=0.8');
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'ReleaseStatus/1.0 (listing verification)',
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await _readLimitedBody(response);
    return verifyFetchedListing(
      titleName: name,
      uri: uri,
      statusCode: response.statusCode,
      body: body,
    );
  } on SocketException {
    return const ListingUrlCheckResult.rejected(
      'Could not reach that listing page. Check the URL and your connection.',
    );
  } on HandshakeException {
    return const ListingUrlCheckResult.rejected(
      'Could not open that listing page securely. Check the URL.',
    );
  } on HttpException {
    return const ListingUrlCheckResult.rejected(
      'That listing page could not be opened. Check the live URL and try again.',
    );
  } on FormatException {
    return const ListingUrlCheckResult.rejected(
      'That listing page returned data this app could not read.',
    );
  } catch (_) {
    return const ListingUrlCheckResult.rejected(
      'Could not verify that listing page. Check the live URL and try again.',
    );
  } finally {
    if (createdClient) {
      client.close(force: true);
    }
  }
}

Future<String> _readLimitedBody(HttpClientResponse response) async {
  final chunks = <int>[];
  const limit = 512 * 1024;
  await for (final chunk in response) {
    final remaining = limit - chunks.length;
    if (remaining <= 0) {
      break;
    }
    if (chunk.length <= remaining) {
      chunks.addAll(chunk);
    } else {
      chunks.addAll(chunk.sublist(0, remaining));
      break;
    }
  }
  return utf8.decode(chunks, allowMalformed: true);
}

import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/monitoring/listing_url_verifier.dart';

void main() {
  test('parseListingUrl accepts http and https hosts', () {
    expect(
      parseListingUrl('https://watch.example/title/marked'),
      isNotNull,
    );
    expect(parseListingUrl('http://example.com/show'), isNotNull);
    expect(parseListingUrl('marked'), isNull);
    expect(parseListingUrl('ftp://example.com/show'), isNull);
    expect(parseListingUrl('https://'), isNull);
  });

  test('a reachable page that mentions the title is verified live', () {
    final result = verifyFetchedListing(
      titleName: 'MARKED',
      uri: Uri.parse('https://watch.example/shows/other'),
      statusCode: 200,
      body: '<html><title>Watch MARKED</title><body>Every tattoo tells a story</body></html>',
    );
    expect(result.isVerifiedLive, isTrue);
    expect(result.normalizedUrl, 'https://watch.example/shows/other');
  });

  test('a URL that contains the title can verify even if the body does not', () {
    final result = verifyFetchedListing(
      titleName: 'Marked',
      uri: Uri.parse('https://watch.example/tv/marked'),
      statusCode: 200,
      body: '<html><body>Loading…</body></html>',
    );
    expect(result.isVerifiedLive, isTrue);
  });

  test('a reachable page that does not mention the title is not live', () {
    final result = verifyFetchedListing(
      titleName: 'MARKED',
      uri: Uri.parse('https://watch.example/home'),
      statusCode: 200,
      body: '<html><body>Browse all shows</body></html>',
    );
    expect(result.isVerifiedLive, isFalse);
    expect(result.errorMessage, contains('title name was not found'));
  });

  test('a missing listing page is not added as live', () {
    final result = verifyFetchedListing(
      titleName: 'MARKED',
      uri: Uri.parse('https://watch.example/tv/marked'),
      statusCode: 404,
      body: 'Not found',
    );
    expect(result.isVerifiedLive, isFalse);
    expect(result.errorMessage, contains('not found'));
  });

  test('verified listing URL marks a manual platform live without TMDb', () {
    final checkedAt = DateTime(2026, 9, 15, 12);
    final platform = applyVerifiedListingLive(
      PlatformStatus.waiting('Relay'),
      checkedAt: checkedAt,
      listingUrl: 'https://watch.example/tv/marked',
    );
    expect(platform.status, DistributionStatus.live);
    expect(platform.evidenceSource, listingUrlAvailabilitySource);
    expect(platform.evidenceUrl, 'https://watch.example/tv/marked');
    expect(platform.isUserConfirmedAvailability, isTrue);
    expect(platform.origin, PlatformOrigin.manual);
  });
}

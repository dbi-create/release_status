import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/cloud/cloud_catalog_codec.dart';
import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  test('cloud rows round-trip a title, listing URL, and settings', () {
    const userId = 'user-1';
    final title = ReleaseTitle(
      id: 'title-1',
      name: 'Marked',
      releaseYear: 2026,
      contentType: 'TV Series',
      placeholderColor: const Color(0xFF3A4A63),
      tmdbId: '335294',
      pinned: true,
      platforms: [
        PlatformStatus(
          platformName: 'Filmhub',
          status: DistributionStatus.live,
          origin: PlatformOrigin.manual,
          evidenceUrl: 'https://example.com/marked',
          evidenceSource: listingUrlAvailabilitySource,
        ),
      ],
    );
    final snapshot = CatalogSnapshot(
      titles: [title],
      createdCount: 4,
      settings: const AppSettings(checkInterval: Duration(hours: 12)),
      existedOnDisk: true,
    );

    final restored = catalogSnapshotFromCloudRows(
      profile: profileRowFromSnapshot(userId: userId, snapshot: snapshot),
      titles: [
        titleRowFromReleaseTitle(userId: userId, title: title),
      ],
      platforms: [
        platformRowFromStatus(
          userId: userId,
          titleId: title.id,
          platform: title.platforms.first,
        ),
      ],
    );

    expect(restored.createdCount, 4);
    expect(restored.settings.checkInterval, const Duration(hours: 12));
    expect(restored.titles, hasLength(1));
    expect(restored.titles.first.name, 'Marked');
    expect(restored.titles.first.tmdbId, '335294');
    expect(restored.titles.first.pinned, isTrue);
    expect(restored.titles.first.platforms, hasLength(1));
    expect(restored.titles.first.platforms.first.evidenceUrl, 'https://example.com/marked');
    expect(
      restored.titles.first.platforms.first.status,
      DistributionStatus.live,
    );
    expect(restored.settings.liveAlertsEnabled, isTrue);
    expect(
      profileRowFromSnapshot(userId: userId, snapshot: snapshot)['live_alerts_enabled'],
      isTrue,
    );
  });
}

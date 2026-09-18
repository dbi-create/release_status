import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/cloud/catalog_sync_merge.dart';
import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_store.dart';

ReleaseTitle _title({
  String id = 'title-1',
  List<PlatformStatus> platforms = const [],
}) {
  return ReleaseTitle(
    id: id,
    name: 'Marked',
    releaseYear: 2026,
    contentType: 'TV Series',
    placeholderColor: const Color(0xFF3A4A63),
    platforms: platforms,
  );
}

CatalogSnapshot _snap(List<ReleaseTitle> titles) {
  return CatalogSnapshot(
    titles: titles,
    createdCount: titles.length,
    settings: const AppSettings(),
    existedOnDisk: true,
  );
}

void main() {
  test('stale cloud snapshot does not delete a channel added on this device', () {
    final catalog = TitleCatalog(
      store: MemoryCatalogStore(
        initial: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
      ),
      initialSnapshot: _snap([
        _title(platforms: [PlatformStatus.waiting('Netflix')]),
      ]),
    );

    catalog.updateTitle(
      catalog.titles.single.copyWith(
        platforms: [
          PlatformStatus.waiting('Netflix'),
          PlatformStatus.waiting('My Stream'),
        ],
      ),
    );
    catalog.applyCloudSnapshot(
      _snap([
        _title(platforms: [PlatformStatus.waiting('Netflix')]),
      ]),
    );

    expect(
      catalog.titles.single.platforms.map((platform) => platform.platformName),
      containsAll(<String>['Netflix', 'My Stream']),
    );
  });

  test('dirty catalog still takes a LIVE verification from another device', () {
    final local = _snap([
      _title(
        platforms: [
          PlatformStatus.waiting('Netflix'),
          PlatformStatus.waiting('My Stream'),
        ],
      ),
    ]);
    final remote = _snap([
      _title(
        platforms: [
          const PlatformStatus(
            platformName: 'Netflix',
            status: DistributionStatus.live,
          ),
        ],
      ),
    ]);

    final merged = mergeRemoteCatalog(
      local: local,
      remote: remote,
      syncedTitleIds: {'title-1'},
      syncedPlatformKeys: {'title-1|Netflix'},
    );
    final platforms = merged.titles.single.platforms;
    expect(
      platforms.map((platform) => platform.platformName),
      containsAll(<String>['Netflix', 'My Stream']),
    );
    expect(
      platforms
          .firstWhere((platform) => platform.platformName == 'Netflix')
          .status,
      DistributionStatus.live,
    );
  });

  test('stale pull after persist keeps a channel this device just added', () async {
    final catalog = TitleCatalog(
      store: MemoryCatalogStore(
        initial: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
      ),
      initialSnapshot: _snap([
        _title(platforms: [PlatformStatus.waiting('Netflix')]),
      ]),
    );
    catalog.applyCloudSnapshot(
      _snap([
        _title(platforms: [PlatformStatus.waiting('Netflix')]),
      ]),
    );
    catalog.updateTitle(
      catalog.titles.single.copyWith(
        platforms: [
          PlatformStatus.waiting('Netflix'),
          PlatformStatus.waiting('Relay'),
        ],
      ),
    );
    await catalog.persistCompleted;
    catalog.applyCloudSnapshot(
      _snap([
        _title(platforms: [PlatformStatus.waiting('Netflix')]),
      ]),
    );
    expect(
      catalog.titles.single.platforms.map((platform) => platform.platformName),
      containsAll(<String>['Netflix', 'Relay']),
    );
  });

  test('pull drops a channel another device deleted after this device had synced it', () {
    final merged = mergeRemoteCatalog(
      local: _snap([
        _title(
          platforms: [
            PlatformStatus.waiting('Netflix'),
            PlatformStatus.waiting('Hulu'),
          ],
        ),
      ]),
      remote: _snap([
        _title(platforms: [PlatformStatus.waiting('Netflix')]),
      ]),
      syncedTitleIds: {'title-1'},
      syncedPlatformKeys: {'title-1|Netflix', 'title-1|Hulu'},
    );
    expect(
      merged.titles.single.platforms.map((platform) => platform.platformName),
      ['Netflix'],
    );
  });

  test('pull keeps a local add that the last cloud snapshot had not seen', () {
    final merged = mergeRemoteCatalog(
      local: _snap([
        _title(
          platforms: [
            PlatformStatus.waiting('Netflix'),
            PlatformStatus.waiting('Relay'),
          ],
        ),
      ]),
      remote: _snap([
        _title(platforms: [PlatformStatus.waiting('Netflix')]),
      ]),
      syncedTitleIds: {'title-1'},
      syncedPlatformKeys: {'title-1|Netflix'},
    );
    expect(
      merged.titles.single.platforms.map((platform) => platform.platformName),
      containsAll(<String>['Netflix', 'Relay']),
    );
  });

  test('push prune ignores channels another device added after last pull', () {
    expect(
      catalogKeysToDelete(
        remoteKeys: {'title-1|Netflix', 'title-1|Plex'},
        localKeys: {'title-1|Netflix'},
        knownKeys: {'title-1|Netflix'},
      ),
      isEmpty,
    );
    expect(
      catalogKeysToDelete(
        remoteKeys: {'title-1|Netflix', 'title-1|Hulu'},
        localKeys: {'title-1|Netflix'},
        knownKeys: {'title-1|Netflix', 'title-1|Hulu'},
      ),
      {'title-1|Hulu'},
    );
  });
}

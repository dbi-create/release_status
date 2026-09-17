import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  test('first launch seeds starter titles and they survive reload', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty(),
    );
    await first.persistCompleted;
    expect(first.titles.map((title) => title.name), contains('MARKED'));

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(second.titles.map((title) => title.name), contains('MARKED'));
    expect(second.totalTitleCount, first.totalTitleCount);
  });

  test('added titles persist across catalog instances', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    first.addTitle(
      name: 'Harbor Light',
      contentType: 'Movie',
      releaseYear: 2022,
      platformNames: const ['Channel Alpha'],
    );
    await first.persistCompleted;

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(second.titles.single.name, 'Harbor Light');
    expect(
      second.titles.single.platforms.single.status,
      DistributionStatus.waiting,
    );
  });

  test('edited titles persist', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    final added = first.addTitle(
      name: 'Harbor Light',
      contentType: 'Movie',
      releaseYear: 2022,
      platformNames: const ['Channel Alpha'],
      tmdbId: '99',
    );
    first.updateTitle(
      added.copyWith(name: 'Harbor Light Revised', tmdbId: '100'),
    );
    await first.persistCompleted;

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(second.titles.single.name, 'Harbor Light Revised');
    expect(second.titles.single.tmdbId, '100');
  });

  test('pinned titles persist and missing pinned defaults to false', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    final added = first.addTitle(
      name: 'Harbor Light',
      contentType: 'Movie',
      releaseYear: 2022,
      platformNames: const ['Channel Alpha'],
    );
    expect(first.pinnedTitles, isEmpty);
    first.setTitlePinned(added.id, true);
    await first.persistCompleted;
    expect(first.pinnedTitles.single.name, 'Harbor Light');

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(second.titles.single.pinned, isTrue);
    expect(second.pinnedTitles.single.name, 'Harbor Light');

    final migrated = releaseTitleFromJson({
      'id': 'old',
      'name': 'Legacy',
      'releaseYear': 2020,
      'contentType': 'Movie',
      'placeholderColor': 0xFF3A4A63,
      'platforms': const <Map<String, Object?>>[],
    });
    expect(migrated.pinned, isFalse);
  });

  test('deleted titles remain deleted', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty(),
    );
    await first.persistCompleted;
    first.removeTitle('marked');
    await first.persistCompleted;

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(second.titleById('marked'), isNull);
    expect(second.titles.map((title) => title.name), isNot(contains('MARKED')));
  });

  test('WAITING, LIVE, and REMOVED persist', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    first.replaceAllTitles([
      ReleaseTitle(
        id: 'one',
        name: 'ONE',
        releaseYear: 2020,
        contentType: 'Movie',
        placeholderColor: const Color(0xFF3A4A63),
        platforms: const [
          PlatformStatus(
            platformName: 'Netflix',
            status: DistributionStatus.live,
            lastCheckedAt: null,
          ),
          PlatformStatus.waiting('Plex'),
          PlatformStatus(
            platformName: 'Amazon',
            status: DistributionStatus.removed,
          ),
        ],
      ),
    ]);
    await first.persistCompleted;

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(second.livePlatformCount, 1);
    expect(second.waitingPlatformCount, 1);
    expect(second.removedPlatformCount, 1);
  });

  test('json file store round-trips a catalog', () async {
    final directory = await Directory.systemTemp.createTemp('release_status_');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonFileCatalogStore(directory: directory);
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty(),
    );
    first.addTitle(
      name: 'Stranger Things',
      contentType: 'TV Series',
      releaseYear: 2016,
      platformNames: const ['Netflix'],
      imdbId: 'tt4574334',
    );
    first.updateSettings(
      const AppSettings(
        monitoringEnabled: false,
        checkInterval: Duration(hours: 12),
      ),
    );
    await first.persistCompleted;

    final loaded = await store.load();
    expect(loaded.existedOnDisk, isTrue);
    expect(loaded.titles.any((title) => title.name == 'MARKED'), isTrue);
    expect(
      loaded.titles.any((title) => title.name == 'Stranger Things'),
      isTrue,
    );
    expect(loaded.settings.monitoringEnabled, isFalse);
    expect(loaded.settings.checkInterval, const Duration(hours: 12));
    expect(encodeCatalogSnapshot(loaded), isNot(contains('TMDB_API_KEY')));
    expect(encodeCatalogSnapshot(loaded), isNot(contains('api_key')));
  });

  test('scheduler metadata persists', () async {
    final store = MemoryCatalogStore();
    final first = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    final checkedAt = DateTime.utc(2026, 9, 14, 18);
    first.updateSettings(
      AppSettings(
        monitoringEnabled: true,
        checkInterval: const Duration(hours: 6),
        lastCompletedCheckAt: checkedAt,
      ),
    );
    await first.persistCompleted;

    final second = TitleCatalog(
      store: store,
      initialSnapshot: await store.load(),
    );
    expect(second.settings.checkInterval.inHours, 6);
    expect(second.settings.lastCompletedCheckAt, checkedAt);
    expect(
      second.settings.nextCheckDue,
      checkedAt.add(const Duration(hours: 6)),
    );
  });

  test('iOS catalog directory uses the sandbox Library folder', () {
    final root = Directory.systemTemp.createTempSync('rs-ios-catalog-');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    Directory('${root.path}/Library').createSync();
    Directory('${root.path}/tmp').createSync();

    expect(
      iosCatalogDirectory(
        home: null,
        temporaryDirectory: Directory('${root.path}/tmp'),
      ).path,
      '${root.path}/Library/Application Support/ReleaseStatus',
    );
    expect(
      iosCatalogDirectory(
        home: '/var/mobile/Containers/Data/Application/ABC',
        temporaryDirectory: Directory('${root.path}/tmp'),
      ).path,
      '/var/mobile/Containers/Data/Application/ABC/Library/Application Support/ReleaseStatus',
    );
    expect(
      iosCatalogDirectory(
        home: '.',
        temporaryDirectory: Directory('${root.path}/tmp'),
      ).path,
      '${root.path}/Library/Application Support/ReleaseStatus',
    );
  });
}

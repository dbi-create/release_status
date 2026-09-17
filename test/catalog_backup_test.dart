import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_backup.dart';
import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('release-status-backup-');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  ReleaseTitle harbor() {
    return const ReleaseTitle(
      id: 'harbor',
      name: 'Harbor Light',
      releaseYear: 2022,
      contentType: 'Movie',
      placeholderColor: Color(0xFF3A4A63),
      platforms: [PlatformStatus.waiting('Relay')],
    );
  }

  test('export writes a backup and restore replaces the catalog', () async {
    final downloads = Directory('${temp.path}/downloads');
    await downloads.create();
    final store = JsonFileCatalogStore(
      directory: temp,
      downloadsDirectory: downloads,
    );
    final catalog = TitleCatalog(
      store: store,
      initialSnapshot: CatalogSnapshot.empty().copyWith(existedOnDisk: true),
    );
    catalog.addTitle(
      name: 'Harbor Light',
      contentType: 'Movie',
      releaseYear: 2022,
      platformNames: const ['Relay'],
    );
    await catalog.persistCompleted;

    final exported = await catalog.exportBackup(
      now: DateTime(2026, 9, 15, 15, 12, 8),
    );
    expect(exported.backupFile.existsSync(), isTrue);
    expect(exported.backupPath, contains('catalog-20260915-151208.json'));
    expect(exported.backupFile.readAsStringSync(), contains('Harbor Light'));
    expect(exported.backupFile.readAsStringSync(), isNot(contains('TMDB')));
    expect(exported.backupFile.readAsStringSync(), isNot(contains('api_key')));
    expect(
      File('${downloads.path}/ReleaseStatus-catalog-20260915-151208.json')
          .existsSync(),
      isTrue,
    );

    catalog.clearAllTitles();
    await catalog.persistCompleted;
    expect(catalog.titles, isEmpty);

    await catalog.restoreLatestBackup();
    await catalog.persistCompleted;
    expect(catalog.titles.single.name, 'Harbor Light');
    expect(catalog.titles.single.platforms.single.platformName, 'Relay');
  });

  test('older backups are pruned', () async {
    final snapshot = CatalogSnapshot(
      titles: [harbor()],
      createdCount: 1,
      settings: const AppSettings(),
      existedOnDisk: true,
    );
    for (var i = 0; i < 22; i++) {
      await exportCatalogBackup(
        snapshot: snapshot,
        catalogDirectory: temp,
        downloadsDirectory: Directory('${temp.path}/missing-downloads'),
        now: DateTime(2026, 9, 15, 0, 0, i),
      );
    }
    final backups = catalogBackupDirectory(temp)
        .listSync()
        .whereType<File>()
        .toList();
    expect(backups, hasLength(maxCatalogBackups));
  });
}

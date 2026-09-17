import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';
import 'package:release_status/storage/status_report.dart';

void main() {
  ReleaseTitle title({
    String id = 'harbor',
    String name = 'Harbor Light',
    int year = 2022,
    List<PlatformStatus> platforms = const [PlatformStatus.waiting('Relay')],
  }) {
    return ReleaseTitle(
      id: id,
      name: name,
      releaseYear: year,
      contentType: 'Movie',
      placeholderColor: const Color(0xFF3A4A63),
      platforms: platforms,
    );
  }

  test('report rows are one per platform and sorted', () {
    final rows = buildStatusReportRows([
      title(
        id: 'z',
        name: 'Zebra',
        platforms: [
          const PlatformStatus.waiting('Tubi'),
          PlatformStatus(
            platformName: 'Amazon',
            status: DistributionStatus.live,
            lastCheckedAt: DateTime(2026, 9, 15, 12),
            evidenceUrl: 'https://example.invalid/amazon',
          ),
        ],
      ),
      title(id: 'a', name: 'Alpha', platforms: const []),
    ]);

    expect(rows, hasLength(3));
    expect(rows[0].title, 'Alpha');
    expect(rows[0].status, 'No platforms');
    expect(rows[1].title, 'Zebra');
    expect(rows[1].platform, 'Amazon');
    expect(rows[1].status, 'LIVE');
    expect(rows[1].listingUrl, 'https://example.invalid/amazon');
    expect(rows[2].platform, 'Tubi');
    expect(rows[2].status, 'NOT LIVE');
    expect(rows[2].lastChecked, 'Not checked');
  });

  test('CSV escapes commas and quotes', () {
    final csv = encodeStatusReportCsv([
      const StatusReportRow(
        title: 'Harbor, "Light"',
        year: '2022',
        contentType: 'Movie',
        platform: 'Relay',
        status: 'REMOVED',
        lastChecked: '15 Sep 2026, 12:00',
        listingUrl: 'https://example.invalid/a,b',
      ),
    ]);
    expect(csv, startsWith('\uFEFF'));
    expect(csv, contains('"Harbor, ""Light"""'));
    expect(csv, contains('"https://example.invalid/a,b"'));
    expect(csv, isNot(contains('TMDB')));
    expect(csv, isNot(contains('api_key')));
  });

  test('HTML escapes markup and is printable', () {
    final html = encodeStatusReportHtml(
      const [
        StatusReportRow(
          title: 'Drill <script>',
          year: '2024',
          contentType: 'TV Series',
          platform: 'VET Tv',
          status: 'NOT LIVE',
          lastChecked: 'Not checked',
          listingUrl: 'https://example.invalid/vet',
        ),
      ],
      generatedAt: DateTime(2026, 9, 15, 16, 4),
    );
    expect(html, contains('Drill &lt;script&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('@media print'));
    expect(html, contains('href="https://example.invalid/vet"'));
    expect(html, contains('Snapshot generated'));
  });

  test('export writes CSV and HTML and copies to Downloads', () async {
    final temp = await Directory.systemTemp.createTemp(
      'release-status-report-',
    );
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });
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

    final exported = await catalog.exportStatusReport(
      now: DateTime(2026, 9, 15, 16, 4, 5),
    );
    expect(exported.csvFile.existsSync(), isTrue);
    expect(exported.htmlFile.existsSync(), isTrue);
    expect(exported.csvPath, contains('status-report-20260915-160405.csv'));
    expect(
      File(
        '${downloads.path}/ReleaseStatus-status-report-20260915-160405.csv',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${downloads.path}/ReleaseStatus-status-report-20260915-160405.html',
      ).existsSync(),
      isTrue,
    );
    final csv = exported.csvFile.readAsStringSync();
    expect(csv, contains('Harbor Light'));
    expect(csv, contains('Relay'));
    expect(csv, contains('NOT LIVE'));
    expect(csv, isNot(contains('TMDB')));
    expect(csv, isNot(contains('api_key')));
  });

  test('older reports are pruned', () async {
    final temp = await Directory.systemTemp.createTemp(
      'release-status-report-prune-',
    );
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });
    final snapshot = CatalogSnapshot(
      titles: [title()],
      createdCount: 1,
      settings: const AppSettings(),
      existedOnDisk: true,
    );
    for (var i = 0; i < 22; i++) {
      await exportStatusReportFiles(
        snapshot: snapshot,
        catalogDirectory: temp,
        downloadsDirectory: Directory('${temp.path}/missing-downloads'),
        now: DateTime(2026, 9, 15, 0, 0, i),
      );
    }
    final files = statusReportDirectory(temp)
        .listSync()
        .whereType<File>()
        .toList();
    expect(files, hasLength(maxStatusReports * 2));
  });

  test('blocked Downloads still saves the local report', () async {
    final temp = await Directory.systemTemp.createTemp(
      'release-status-report-blocked-',
    );
    addTearDown(() async {
      await Process.run('chmod', ['755', '${temp.path}/downloads']);
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });
    final downloads = Directory('${temp.path}/downloads');
    await downloads.create();
    final chmod = await Process.run('chmod', ['555', downloads.path]);
    expect(chmod.exitCode, 0);

    final snapshot = CatalogSnapshot(
      titles: [title()],
      createdCount: 1,
      settings: const AppSettings(),
      existedOnDisk: true,
    );
    final exported = await exportStatusReportFiles(
      snapshot: snapshot,
      catalogDirectory: temp,
      downloadsDirectory: downloads,
      now: DateTime(2026, 9, 15, 16, 21, 14),
    );
    expect(exported.csvFile.existsSync(), isTrue);
    expect(exported.htmlFile.existsSync(), isTrue);
    expect(exported.downloadsCsvFile, isNull);
    expect(exported.downloadsHtmlFile, isNull);
  });
}

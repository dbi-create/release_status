import 'dart:io';

import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/storage/catalog_backup.dart';
import 'package:release_status/storage/catalog_store.dart';

const int maxStatusReports = 20;

class StatusReportRow {
  const StatusReportRow({
    required this.title,
    required this.year,
    required this.contentType,
    required this.platform,
    required this.status,
    required this.lastChecked,
    required this.listingUrl,
  });

  final String title;
  final String year;
  final String contentType;
  final String platform;
  final String status;
  final String lastChecked;
  final String listingUrl;
}

class StatusReportExportResult {
  const StatusReportExportResult({
    required this.csvFile,
    required this.htmlFile,
    this.downloadsCsvFile,
    this.downloadsHtmlFile,
  });

  final File csvFile;
  final File htmlFile;
  final File? downloadsCsvFile;
  final File? downloadsHtmlFile;

  String get csvPath => csvFile.path;

  String get htmlPath => htmlFile.path;

  String? get downloadsCsvPath => downloadsCsvFile?.path;

  String? get downloadsHtmlPath => downloadsHtmlFile?.path;
}

Directory statusReportDirectory(Directory catalogDirectory) {
  return Directory('${catalogDirectory.path}/reports');
}

String statusReportFileStem(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'status-report-${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}';
}

List<StatusReportRow> buildStatusReportRows(Iterable<ReleaseTitle> titles) {
  final sortedTitles = [...titles]
    ..sort((left, right) {
      final byName = left.name.toLowerCase().compareTo(right.name.toLowerCase());
      if (byName != 0) {
        return byName;
      }
      return left.releaseYear.compareTo(right.releaseYear);
    });

  final rows = <StatusReportRow>[];
  for (final title in sortedTitles) {
    if (title.platforms.isEmpty) {
      rows.add(
        StatusReportRow(
          title: title.name,
          year: '${title.releaseYear}',
          contentType: title.contentType,
          platform: '',
          status: 'No platforms',
          lastChecked: '',
          listingUrl: '',
        ),
      );
      continue;
    }
    final platforms = [...title.platforms]
      ..sort(
        (left, right) => left.platformName.toLowerCase().compareTo(
          right.platformName.toLowerCase(),
        ),
      );
    for (final platform in platforms) {
      rows.add(
        StatusReportRow(
          title: title.name,
          year: '${title.releaseYear}',
          contentType: title.contentType,
          platform: platform.platformName,
          status: platform.statusLabel,
          lastChecked: _lastCheckedValue(platform),
          listingUrl: platform.evidenceUrl?.trim() ?? '',
        ),
      );
    }
  }
  return rows;
}

String encodeStatusReportCsv(List<StatusReportRow> rows) {
  final buffer = StringBuffer()
    ..write('\uFEFF')
    ..writeln(
      _csvLine(const [
        'Title',
        'Year',
        'Type',
        'Platform',
        'Status',
        'Last checked',
        'Listing URL',
      ]),
    );
  for (final row in rows) {
    buffer.writeln(
      _csvLine([
        row.title,
        row.year,
        row.contentType,
        row.platform,
        row.status,
        row.lastChecked,
        row.listingUrl,
      ]),
    );
  }
  return buffer.toString();
}

String encodeStatusReportHtml(
  List<StatusReportRow> rows, {
  required DateTime generatedAt,
}) {
  final generated = formatStoredTimestamp(generatedAt);
  final body = StringBuffer();
  if (rows.isEmpty) {
    body.writeln('<p>No titles in this catalog.</p>');
  } else {
    body
      ..writeln('<table>')
      ..writeln(
        '<thead><tr><th>Title</th><th>Year</th><th>Type</th>'
        '<th>Platform</th><th>Status</th><th>Last checked</th>'
        '<th>Listing URL</th></tr></thead>',
      )
      ..writeln('<tbody>');
    for (final row in rows) {
      body.writeln(
        '<tr>'
        '<td>${_htmlEscape(row.title)}</td>'
        '<td>${_htmlEscape(row.year)}</td>'
        '<td>${_htmlEscape(row.contentType)}</td>'
        '<td>${_htmlEscape(row.platform)}</td>'
        '<td>${_htmlEscape(row.status)}</td>'
        '<td>${_htmlEscape(row.lastChecked)}</td>'
        '<td>${_htmlListingCell(row.listingUrl)}</td>'
        '</tr>',
      );
    }
    body
      ..writeln('</tbody>')
      ..writeln('</table>');
  }

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>ReleaseStatus report</title>
<style>
  body { font-family: system-ui, sans-serif; color: #111; background: #fff; margin: 32px; }
  h1 { font-size: 22px; margin: 0 0 8px; }
  p { color: #444; margin: 0 0 20px; }
  table { border-collapse: collapse; width: 100%; font-size: 13px; }
  th, td { border: 1px solid #ccc; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: #f3f3f3; }
  a { color: #111; }
  @media print {
    body { margin: 12px; }
    a { text-decoration: none; }
  }
</style>
</head>
<body>
<h1>ReleaseStatus</h1>
<p>Snapshot generated $generated. This is local catalog status, not a live scan.</p>
${body.toString()}
</body>
</html>
''';
}

Future<StatusReportExportResult> exportStatusReportFiles({
  required CatalogSnapshot snapshot,
  required Directory catalogDirectory,
  Directory? downloadsDirectory,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final stem = statusReportFileStem(at);
  final reportDir = statusReportDirectory(catalogDirectory);
  await reportDir.create(recursive: true);

  final rows = buildStatusReportRows(snapshot.titles);
  final csv = encodeStatusReportCsv(rows);
  final html = encodeStatusReportHtml(rows, generatedAt: at);

  final csvFile = File('${reportDir.path}/$stem.csv');
  final htmlFile = File('${reportDir.path}/$stem.html');
  await csvFile.writeAsString(csv);
  await htmlFile.writeAsString(html);
  await _pruneOldReports(reportDir);

  final downloadsCsv = await tryWriteDownloadsCopy(
    downloadsDirectory: downloadsDirectory,
    fileName: 'ReleaseStatus-$stem.csv',
    contents: csv,
  );
  final downloadsHtml = await tryWriteDownloadsCopy(
    downloadsDirectory: downloadsDirectory,
    fileName: 'ReleaseStatus-$stem.html',
    contents: html,
  );

  return StatusReportExportResult(
    csvFile: csvFile,
    htmlFile: htmlFile,
    downloadsCsvFile: downloadsCsv,
    downloadsHtmlFile: downloadsHtml,
  );
}

String _lastCheckedValue(PlatformStatus platform) {
  if (platform.lastCheckedAt != null) {
    return formatStoredTimestamp(platform.lastCheckedAt!);
  }
  final label = platform.lastCheckedLabel?.trim() ?? '';
  if (label.isNotEmpty) {
    return label;
  }
  return 'Not checked';
}

String _csvLine(List<String> values) {
  return values.map(_csvField).join(',');
}

String _csvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

String _htmlListingCell(String url) {
  if (url.isEmpty) {
    return '';
  }
  final escaped = _htmlEscape(url);
  return '<a href="$escaped">$escaped</a>';
}

Future<void> _pruneOldReports(Directory reportDir) async {
  final files = reportDir
      .listSync()
      .whereType<File>()
      .where((file) {
        final path = file.path;
        return path.endsWith('.csv') || path.endsWith('.html');
      })
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  final extra = files.length - (maxStatusReports * 2);
  if (extra <= 0) {
    return;
  }
  for (final file in files.take(extra)) {
    await file.delete();
  }
}

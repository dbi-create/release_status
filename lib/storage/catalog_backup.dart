import 'dart:io';

import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';

const int maxCatalogBackups = 20;

class CatalogExportResult {
  const CatalogExportResult({
    required this.backupFile,
    this.downloadsFile,
  });

  final File backupFile;
  final File? downloadsFile;

  String get backupPath => backupFile.path;

  String? get downloadsPath => downloadsFile?.path;
}

Directory catalogBackupDirectory(Directory catalogDirectory) {
  return Directory('${catalogDirectory.path}/backups');
}

Directory? defaultDownloadsDirectory() {
  if (Platform.isIOS) {
    return null;
  }
  if (Platform.isWindows) {
    final profile = Platform.environment['USERPROFILE'];
    if (profile == null || profile.isEmpty) {
      return null;
    }
    return Directory('$profile\\Downloads');
  }
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return null;
  }
  // Sandboxed macOS apps get a container home. That Downloads folder is not
  // the user's real Downloads and is often not writable.
  if (home.contains('/Library/Containers/')) {
    return null;
  }
  return Directory('$home/Downloads');
}

/// Best-effort copy. Failures must not fail the local Application Support save.
Future<File?> tryWriteDownloadsCopy({
  required Directory? downloadsDirectory,
  required String fileName,
  required String contents,
}) async {
  final downloads = downloadsDirectory ?? defaultDownloadsDirectory();
  if (downloads == null) {
    return null;
  }
  try {
    if (!await downloads.exists()) {
      return null;
    }
    final file = File('${downloads.path}/$fileName');
    await file.writeAsString(contents);
    return file;
  } on FileSystemException {
    return null;
  }
}

String catalogBackupFileName(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'catalog-${at.year}${two(at.month)}${two(at.day)}-'
      '${two(at.hour)}${two(at.minute)}${two(at.second)}.json';
}

Future<CatalogExportResult> exportCatalogBackup({
  required CatalogSnapshot snapshot,
  required Directory catalogDirectory,
  Directory? downloadsDirectory,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final name = catalogBackupFileName(at);
  final backupDir = catalogBackupDirectory(catalogDirectory);
  await backupDir.create(recursive: true);
  final backupFile = File('${backupDir.path}/$name');
  final encoded = encodeCatalogSnapshot(snapshot);
  await backupFile.writeAsString(encoded);
  await _pruneOldBackups(backupDir);

  final downloadsFile = await tryWriteDownloadsCopy(
    downloadsDirectory: downloadsDirectory,
    fileName: 'ReleaseStatus-$name',
    contents: encoded,
  );

  return CatalogExportResult(
    backupFile: backupFile,
    downloadsFile: downloadsFile,
  );
}

Future<File?> latestCatalogBackup(Directory catalogDirectory) async {
  final backupDir = catalogBackupDirectory(catalogDirectory);
  if (!await backupDir.exists()) {
    return null;
  }
  final files = backupDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList(growable: false)
    ..sort((left, right) => left.path.compareTo(right.path));
  if (files.isEmpty) {
    return null;
  }
  return files.last;
}

Future<CatalogSnapshot> importCatalogBackup(File file) async {
  final source = await file.readAsString();
  if (source.trim().isEmpty) {
    throw const FormatException('Backup file is empty.');
  }
  return decodeCatalogSnapshot(source, existedOnDisk: true);
}

Future<void> _pruneOldBackups(Directory backupDir) async {
  final files = backupDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  final extra = files.length - maxCatalogBackups;
  if (extra <= 0) {
    return;
  }
  for (final file in files.take(extra)) {
    await file.delete();
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/match_confidence.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/platform_status_event.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/storage/catalog_store.dart';

Map<String, Object?> catalogSnapshotToJson(CatalogSnapshot snapshot) {
  return {
    'schemaVersion': CatalogSnapshot.currentSchemaVersion,
    'createdCount': snapshot.createdCount,
    'settings': snapshot.settings.toJson(),
    'titles': [for (final title in snapshot.titles) releaseTitleToJson(title)],
  };
}

CatalogSnapshot catalogSnapshotFromJson(
  Map<String, Object?> json, {
  required bool existedOnDisk,
}) {
  final titlesRaw = json['titles'];
  return CatalogSnapshot(
    schemaVersion: json['schemaVersion'] as int? ?? 1,
    createdCount: json['createdCount'] as int? ?? 0,
    settings: AppSettings.fromJson(
      json['settings'] is Map<String, Object?>
          ? json['settings'] as Map<String, Object?>
          : json['settings'] is Map
          ? Map<String, Object?>.from(json['settings'] as Map)
          : null,
    ),
    titles: [
      if (titlesRaw is List)
        for (final raw in titlesRaw)
          if (raw is Map) releaseTitleFromJson(Map<String, Object?>.from(raw)),
    ],
    existedOnDisk: existedOnDisk,
  );
}

Map<String, Object?> releaseTitleToJson(ReleaseTitle title) {
  return {
    'id': title.id,
    'name': title.name,
    'releaseYear': title.releaseYear,
    'contentType': title.contentType,
    'placeholderColor': title.placeholderColor.toARGB32(),
    'imdbId': title.imdbId,
    'tmdbId': title.tmdbId,
    'availabilityProviderId': title.availabilityProviderId,
    'posterUrl': title.posterUrl,
    'director': title.director,
    'producer': title.producer,
    'writer': title.writer,
    'alternateTitle': title.alternateTitle,
    'pinned': title.pinned,
    'lastLookedUpAt': title.lastLookedUpAt?.toIso8601String(),
    'discoveredPlatforms': [
      for (final listing in title.discoveredPlatforms) listing.toJson(),
    ],
    'platforms': [
      for (final platform in title.platforms) platformStatusToJson(platform),
    ],
  };
}

ReleaseTitle releaseTitleFromJson(Map<String, Object?> json) {
  final platformsRaw = json['platforms'];
  return ReleaseTitle(
    id: json['id'] as String,
    name: json['name'] as String,
    releaseYear: json['releaseYear'] as int,
    contentType: json['contentType'] as String,
    placeholderColor: Color(json['placeholderColor'] as int? ?? 0xFF3A4A63),
    imdbId: json['imdbId'] as String?,
    tmdbId: json['tmdbId'] as String?,
    availabilityProviderId: json['availabilityProviderId'] as String?,
    posterUrl: json['posterUrl'] as String?,
    director: json['director'] as String?,
    producer: json['producer'] as String?,
    writer: json['writer'] as String?,
    alternateTitle: json['alternateTitle'] as String?,
    pinned: json['pinned'] as bool? ?? false,
    lastLookedUpAt: _date(json['lastLookedUpAt']),
    discoveredPlatforms: [
      if (json['discoveredPlatforms'] is List)
        for (final raw in json['discoveredPlatforms'] as List)
          if (raw is Map)
            DiscoveredPlatform.fromJson(Map<String, Object?>.from(raw)),
    ],
    platforms: [
      if (platformsRaw is List)
        for (final raw in platformsRaw)
          if (raw is Map)
            platformStatusFromJson(Map<String, Object?>.from(raw)),
    ],
  );
}

Map<String, Object?> platformStatusToJson(PlatformStatus platform) {
  return {
    'platformName': platform.platformName,
    'status': platform.status.name,
    'firstDetectedLabel': platform.firstDetectedLabel,
    'lastCheckedLabel': platform.lastCheckedLabel,
    'lastCheckedAt': platform.lastCheckedAt?.toIso8601String(),
    'firstDetectedAt': platform.firstDetectedAt?.toIso8601String(),
    'removedAt': platform.removedAt?.toIso8601String(),
    'statusMessage': platform.statusMessage,
    'statusDetail': platform.statusDetail,
    'evidenceSource': platform.evidenceSource,
    'evidenceUrl': platform.evidenceUrl,
    'lastMonitoringSource': platform.lastMonitoringSource,
    'lastMatchConfidence': platform.lastMatchConfidence?.name,
    'lastCheckFailed': platform.lastCheckFailed,
    'consecutiveVerifiedAbsences': platform.consecutiveVerifiedAbsences,
    'origin': platform.origin.name,
    'licenseRelationship': platform.licenseRelationship.name,
    'sourceProviderId': platform.sourceProviderId,
    'history': [for (final event in platform.history) event.toJson()],
  };
}

PlatformStatus platformStatusFromJson(Map<String, Object?> json) {
  final historyRaw = json['history'];
  return PlatformStatus(
    platformName: json['platformName'] as String,
    status:
        _statusFromName(json['status'] as String?) ??
        DistributionStatus.waiting,
    firstDetectedLabel: json['firstDetectedLabel'] as String?,
    lastCheckedLabel: json['lastCheckedLabel'] as String?,
    lastCheckedAt: _date(json['lastCheckedAt']),
    firstDetectedAt: _date(json['firstDetectedAt']),
    removedAt: _date(json['removedAt']),
    statusMessage: json['statusMessage'] as String?,
    statusDetail: json['statusDetail'] as String?,
    evidenceSource: json['evidenceSource'] as String?,
    evidenceUrl: json['evidenceUrl'] as String?,
    lastMonitoringSource: json['lastMonitoringSource'] as String?,
    lastMatchConfidence: _confidenceFromName(
      json['lastMatchConfidence'] as String?,
    ),
    lastCheckFailed: json['lastCheckFailed'] as bool? ?? false,
    consecutiveVerifiedAbsences:
        json['consecutiveVerifiedAbsences'] as int? ?? 0,
    origin: platformOriginFromName(json['origin'] as String?),
    licenseRelationship: licenseRelationshipFromName(
      json['licenseRelationship'] as String?,
    ),
    sourceProviderId: json['sourceProviderId'] as String?,
    history: [
      if (historyRaw is List)
        for (final raw in historyRaw)
          if (raw is Map)
            PlatformStatusEvent.fromJson(Map<String, Object?>.from(raw)),
    ],
  );
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

DistributionStatus? _statusFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final status in DistributionStatus.values) {
    if (status.name == name) {
      return status;
    }
  }
  return null;
}

MatchConfidence? _confidenceFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final value in MatchConfidence.values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

String encodeCatalogSnapshot(CatalogSnapshot snapshot) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(catalogSnapshotToJson(snapshot));
}

CatalogSnapshot decodeCatalogSnapshot(
  String source, {
  required bool existedOnDisk,
}) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Catalog file is not a JSON object.');
  }
  return catalogSnapshotFromJson(
    Map<String, Object?>.from(decoded),
    existedOnDisk: existedOnDisk,
  );
}

/// Resolves a durable local folder without extra packages.
///
/// macOS/Linux/Windows use standard per-user application data paths.
/// iOS HOME is often unset in Dart, so the catalog is derived from the
/// sandbox that owns the temp directory.
Directory defaultCatalogDirectory() {
  if (Platform.isIOS) {
    return iosCatalogDirectory(
      home: Platform.environment['HOME'],
      temporaryDirectory: Directory.systemTemp,
    );
  }
  if (Platform.isMacOS) {
    return Directory(
      '${Platform.environment['HOME']}/Library/Application Support/ReleaseStatus',
    );
  }
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ?? '.';
    return Directory('$appData\\ReleaseStatus');
  }
  final home = Platform.environment['HOME'] ?? '.';
  if (Platform.isLinux) {
    return Directory('$home/.local/share/ReleaseStatus');
  }
  return Directory('$home/Library/Application Support/ReleaseStatus');
}

/// iOS app-container Application Support, without path_provider.
Directory iosCatalogDirectory({
  required String? home,
  required Directory temporaryDirectory,
}) {
  if (home != null && home.startsWith('/')) {
    return Directory('$home/Library/Application Support/ReleaseStatus');
  }
  var dir = temporaryDirectory;
  for (var i = 0; i < 6; i++) {
    final library = Directory('${dir.path}/Library');
    if (library.existsSync()) {
      return Directory('${dir.path}/Library/Application Support/ReleaseStatus');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return Directory('${temporaryDirectory.path}/ReleaseStatus');
}

class JsonFileCatalogStore implements CatalogStore {
  JsonFileCatalogStore({
    Directory? directory,
    this.downloadsDirectory,
  }) : directory = directory ?? defaultCatalogDirectory();

  final Directory directory;
  final Directory? downloadsDirectory;

  File get _file => File('${directory.path}/catalog.json');

  @override
  Future<CatalogSnapshot> load() async {
    if (!await _file.exists()) {
      return CatalogSnapshot.empty();
    }
    final source = await _file.readAsString();
    if (source.trim().isEmpty) {
      return CatalogSnapshot.empty().copyWith(existedOnDisk: true);
    }
    return decodeCatalogSnapshot(source, existedOnDisk: true);
  }

  @override
  Future<void> save(CatalogSnapshot snapshot) async {
    await directory.create(recursive: true);
    final encoded = encodeCatalogSnapshot(snapshot);
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(encoded, flush: true);
    if (await _file.exists()) {
      await _file.delete();
    }
    if (await temp.exists()) {
      await temp.copy(_file.path);
      if (await temp.exists()) {
        await temp.delete();
      }
      return;
    }
    await _file.writeAsString(encoded, flush: true);
  }
}

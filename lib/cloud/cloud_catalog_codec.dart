import 'dart:ui';

import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';

Map<String, Object?> profileRowFromSnapshot({
  required String userId,
  required CatalogSnapshot snapshot,
}) {
  return {
    'user_id': userId,
    'monitoring_enabled': snapshot.settings.monitoringEnabled,
    'check_interval_hours': snapshot.settings.checkInterval.inHours,
    'last_completed_check_at': snapshot.settings.lastCompletedCheckAt
        ?.toUtc()
        .toIso8601String(),
    'notifications_cleared_at': snapshot.settings.notificationsClearedAt
        ?.toUtc()
        .toIso8601String(),
    'catalog_created_count': snapshot.createdCount,
    'live_alerts_enabled': snapshot.settings.liveAlertsEnabled,
  };
}

Map<String, Object?> titleRowFromReleaseTitle({
  required String userId,
  required ReleaseTitle title,
}) {
  return {
    'owner_user_id': userId,
    'id': title.id,
    'name': title.name,
    'release_year': title.releaseYear,
    'content_type': title.contentType,
    'placeholder_color': title.placeholderColor.toARGB32(),
    'imdb_id': title.imdbId,
    'tmdb_id': title.tmdbId,
    'availability_provider_id': title.availabilityProviderId,
    'poster_url': title.posterUrl,
    'director': title.director,
    'producer': title.producer,
    'writer': title.writer,
    'alternate_title': title.alternateTitle,
    'pinned': title.pinned,
    'last_looked_up_at': title.lastLookedUpAt?.toUtc().toIso8601String(),
    'discovered_platforms': [
      for (final listing in title.discoveredPlatforms) listing.toJson(),
    ],
  };
}

Map<String, Object?> platformRowFromStatus({
  required String userId,
  required String titleId,
  required PlatformStatus platform,
}) {
  final json = platformStatusToJson(platform);
  return {
    'owner_user_id': userId,
    'title_id': titleId,
    'platform_name': platform.platformName,
    'status': platform.status.name,
    'origin': platform.origin.name,
    'license_relationship': platform.licenseRelationship.name,
    'first_detected_at': platform.firstDetectedAt?.toUtc().toIso8601String(),
    'last_checked_at': platform.lastCheckedAt?.toUtc().toIso8601String(),
    'removed_at': platform.removedAt?.toUtc().toIso8601String(),
    'status_message': platform.statusMessage,
    'status_detail': platform.statusDetail,
    'evidence_source': platform.evidenceSource,
    'evidence_url': platform.evidenceUrl,
    'last_monitoring_source': platform.lastMonitoringSource,
    'last_match_confidence': platform.lastMatchConfidence?.name,
    'last_check_failed': platform.lastCheckFailed,
    'consecutive_verified_absences': platform.consecutiveVerifiedAbsences,
    'source_provider_id': platform.sourceProviderId,
    'history': json['history'],
  };
}

CatalogSnapshot catalogSnapshotFromCloudRows({
  required Map<String, Object?>? profile,
  required List<Map<String, Object?>> titles,
  required List<Map<String, Object?>> platforms,
}) {
  final byTitle = <String, List<Map<String, Object?>>>{};
  for (final row in platforms) {
    final titleId = row['title_id'] as String? ?? '';
    byTitle.putIfAbsent(titleId, () => []).add(row);
  }

  return CatalogSnapshot(
    existedOnDisk: true,
    createdCount: profile?['catalog_created_count'] as int? ?? titles.length,
    settings: AppSettings(
      monitoringEnabled: profile?['monitoring_enabled'] as bool? ?? true,
      checkInterval: Duration(
        hours: profile?['check_interval_hours'] as int? ?? 24,
      ),
      lastCompletedCheckAt: _date(profile?['last_completed_check_at']),
      notificationsClearedAt: _date(profile?['notifications_cleared_at']),
      liveAlertsEnabled: profile?['live_alerts_enabled'] as bool? ?? true,
    ),
    titles: [
      for (final row in titles)
        _titleFromRow(row, byTitle[row['id'] as String? ?? ''] ?? const []),
    ],
  );
}

ReleaseTitle _titleFromRow(
  Map<String, Object?> row,
  List<Map<String, Object?>> platformRows,
) {
  final discoveredRaw = row['discovered_platforms'];
  return ReleaseTitle(
    id: row['id'] as String,
    name: row['name'] as String? ?? '',
    releaseYear: row['release_year'] as int? ?? 0,
    contentType: row['content_type'] as String? ?? 'Movie',
    placeholderColor: Color(
      row['placeholder_color'] as int? ?? 0xFF3A4A63,
    ),
    imdbId: row['imdb_id'] as String?,
    tmdbId: row['tmdb_id'] as String?,
    availabilityProviderId: row['availability_provider_id'] as String?,
    posterUrl: row['poster_url'] as String?,
    director: row['director'] as String?,
    producer: row['producer'] as String?,
    writer: row['writer'] as String?,
    alternateTitle: row['alternate_title'] as String?,
    pinned: row['pinned'] as bool? ?? false,
    lastLookedUpAt: _date(row['last_looked_up_at']),
    discoveredPlatforms: [
      if (discoveredRaw is List)
        for (final raw in discoveredRaw)
          if (raw is Map)
            DiscoveredPlatform.fromJson(Map<String, Object?>.from(raw)),
    ],
    platforms: [
      for (final platform in platformRows) _platformFromRow(platform),
    ],
  );
}

PlatformStatus _platformFromRow(Map<String, Object?> row) {
  return platformStatusFromJson({
    'platformName': row['platform_name'],
    'status': row['status'],
    'lastCheckedAt': row['last_checked_at'],
    'firstDetectedAt': row['first_detected_at'],
    'removedAt': row['removed_at'],
    'statusMessage': row['status_message'],
    'statusDetail': row['status_detail'],
    'evidenceSource': row['evidence_source'],
    'evidenceUrl': row['evidence_url'],
    'lastMonitoringSource': row['last_monitoring_source'],
    'lastMatchConfidence': row['last_match_confidence'],
    'lastCheckFailed': row['last_check_failed'],
    'consecutiveVerifiedAbsences': row['consecutive_verified_absences'],
    'origin': row['origin'],
    'licenseRelationship': row['license_relationship'],
    'sourceProviderId': row['source_provider_id'],
    'history': row['history'],
  });
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

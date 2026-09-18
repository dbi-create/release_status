import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/storage/catalog_store.dart';

String catalogTitleKey(String titleId) => titleId;

String catalogPlatformKey(String titleId, String platformName) =>
    '$titleId|$platformName';

Set<String> catalogTitleKeys(Iterable<ReleaseTitle> titles) {
  return {for (final title in titles) title.id};
}

Set<String> catalogPlatformKeys(Iterable<ReleaseTitle> titles) {
  return {
    for (final title in titles)
      for (final platform in title.platforms)
        catalogPlatformKey(title.id, platform.platformName),
  };
}

/// Remote rows this device knew about and then removed.
Set<String> catalogKeysToDelete({
  required Set<String> remoteKeys,
  required Set<String> localKeys,
  required Set<String> knownKeys,
}) {
  return {
    for (final key in remoteKeys)
      if (!localKeys.contains(key) && knownKeys.contains(key)) key,
  };
}

/// Keep in-progress local edits, and still pick up channels added or verified
/// on another device.
CatalogSnapshot mergeRemoteCatalog({
  required CatalogSnapshot local,
  required CatalogSnapshot remote,
  required Set<String> syncedTitleIds,
  required Set<String> syncedPlatformKeys,
}) {
  final localById = {for (final title in local.titles) title.id: title};
  final remoteById = {for (final title in remote.titles) title.id: title};
  final next = <ReleaseTitle>[];
  for (final localTitle in local.titles) {
    final remoteTitle = remoteById[localTitle.id];
    if (remoteTitle == null) {
      if (syncedTitleIds.contains(localTitle.id)) {
        continue;
      }
      next.add(localTitle);
      continue;
    }
    next.add(
      _mergeTitle(
        local: localTitle,
        remote: remoteTitle,
        syncedPlatformKeys: syncedPlatformKeys,
      ),
    );
  }
  for (final remoteTitle in remote.titles) {
    if (localById.containsKey(remoteTitle.id)) {
      continue;
    }
    next.add(remoteTitle);
  }
  return local.copyWith(
    titles: next,
    createdCount: local.createdCount >= remote.createdCount
        ? local.createdCount
        : remote.createdCount,
    existedOnDisk: true,
  );
}

ReleaseTitle _mergeTitle({
  required ReleaseTitle local,
  required ReleaseTitle remote,
  required Set<String> syncedPlatformKeys,
}) {
  final localByName = {
    for (final platform in local.platforms) platform.platformName: platform,
  };
  final remoteByName = {
    for (final platform in remote.platforms) platform.platformName: platform,
  };
  final mergedPlatforms = <PlatformStatus>[];
  for (final localPlatform in local.platforms) {
    final remotePlatform = remoteByName[localPlatform.platformName];
    if (remotePlatform != null) {
      mergedPlatforms.add(_preferPlatform(localPlatform, remotePlatform));
      continue;
    }
    final key = catalogPlatformKey(local.id, localPlatform.platformName);
    if (syncedPlatformKeys.contains(key)) {
      continue;
    }
    mergedPlatforms.add(localPlatform);
  }
  for (final remotePlatform in remote.platforms) {
    if (localByName.containsKey(remotePlatform.platformName)) {
      continue;
    }
    mergedPlatforms.add(remotePlatform);
  }
  return local.copyWith(
    platforms: mergedPlatforms,
    tmdbId: local.tmdbId ?? remote.tmdbId,
    imdbId: local.imdbId ?? remote.imdbId,
    posterUrl: local.posterUrl ?? remote.posterUrl,
    director: local.director ?? remote.director,
    producer: local.producer ?? remote.producer,
    writer: local.writer ?? remote.writer,
    lastLookedUpAt: _laterDate(local.lastLookedUpAt, remote.lastLookedUpAt),
    pinned: local.pinned || remote.pinned,
  );
}

PlatformStatus _preferPlatform(PlatformStatus local, PlatformStatus remote) {
  final localRank = _statusRank(local.status);
  final remoteRank = _statusRank(remote.status);
  if (remoteRank > localRank) {
    return remote;
  }
  if (localRank > remoteRank) {
    return local;
  }
  final remoteChecked = remote.lastCheckedAt;
  final localChecked = local.lastCheckedAt;
  if (remoteChecked != null &&
      (localChecked == null || remoteChecked.isAfter(localChecked))) {
    return remote;
  }
  return local;
}

int _statusRank(DistributionStatus status) {
  switch (status) {
    case DistributionStatus.live:
      return 3;
    case DistributionStatus.originalNetwork:
      return 2;
    case DistributionStatus.waiting:
      return 1;
    case DistributionStatus.removed:
      return 0;
  }
}

DateTime? _laterDate(DateTime? left, DateTime? right) {
  if (left == null) {
    return right;
  }
  if (right == null) {
    return left;
  }
  return right.isAfter(left) ? right : left;
}

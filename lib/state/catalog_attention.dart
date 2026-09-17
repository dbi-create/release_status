import 'package:release_status/models/release_title.dart';

class AttentionItem {
  const AttentionItem({
    required this.titleId,
    required this.titleName,
    required this.summary,
    this.platformName,
    this.platformCount,
  });

  final String titleId;
  final String titleName;
  final String summary;
  final String? platformName;
  final int? platformCount;
}

class CatalogAttention {
  const CatalogAttention({required this.discoveredByTitle});

  final List<AttentionItem> discoveredByTitle;

  bool get isEmpty => discoveredByTitle.isEmpty;

  int get notificationCount => discoveredByTitle.length;
}

CatalogAttention catalogAttention(
  List<ReleaseTitle> titles, {
  DateTime? notificationsClearedAt,
}) {
  final discoveredByTitle = <AttentionItem>[];

  for (final title in titles) {
    final lookedUpAt = title.lastLookedUpAt ?? _inferredLookedUpAt(title);
    if (lookedUpAt == null) {
      continue;
    }
    if (notificationsClearedAt != null &&
        !lookedUpAt.isAfter(notificationsClearedAt)) {
      continue;
    }

    final count = title.licensedPlatformCount;
    discoveredByTitle.add(
      AttentionItem(
        titleId: title.id,
        titleName: title.name,
        platformCount: count,
        summary: count == 1
            ? '${title.name} is on 1 platform.'
            : '${title.name} is on $count platforms.',
      ),
    );
  }

  return CatalogAttention(discoveredByTitle: discoveredByTitle);
}

DateTime? _inferredLookedUpAt(ReleaseTitle title) {
  DateTime? latest;
  for (final platform in title.platforms) {
    final checkedAt = platform.lastCheckedAt;
    if (checkedAt == null) {
      continue;
    }
    if (latest == null || checkedAt.isAfter(latest)) {
      latest = checkedAt;
    }
  }
  if (latest != null) {
    return latest;
  }
  final tmdbId = title.tmdbId?.trim();
  if (tmdbId != null && tmdbId.isNotEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return null;
}

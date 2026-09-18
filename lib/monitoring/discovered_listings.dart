import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/match_confidence.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/monitoring/discovery_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/platform_aliases.dart';

/// Deduplicates public listings and drops any that already match a licensed
/// platform name. Aliases are used only for comparison, not as evidence.
List<DiscoveredPlatform> listingsMissingFromLicensed({
  required Iterable<DiscoveredPlatform> listings,
  required Iterable<String> licensedPlatformNames,
}) {
  final seen = <String>{};
  final missing = <DiscoveredPlatform>[];
  for (final listing in listings) {
    final name = listing.providerName.trim();
    if (name.isEmpty) {
      continue;
    }
    final alreadyLicensed = licensedPlatformNames.any(
      (licensed) => PlatformAliases.sameChannel(
        leftName: licensed,
        rightName: name,
        rightUrl: listing.listingUrl,
      ),
    );
    if (alreadyLicensed) {
      continue;
    }
    final key =
        PlatformAliases.canonicalId(name) ?? PlatformAliases.normalize(name);
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    missing.add(listing);
  }
  missing.sort(
    (left, right) => left.providerName.toLowerCase().compareTo(
      right.providerName.toLowerCase(),
    ),
  );
  return missing;
}

/// Applies the same TMDb result as Check Status: US watch offers go live,
/// original networks are marked AIRS ON.
List<PlatformStatus> applyDiscoveredPlatforms({
  required List<PlatformStatus> current,
  required Iterable<DiscoveredAvailability> listings,
  DateTime? checkedAt,
}) {
  final now = checkedAt ?? DateTime.now();
  final discovered = listings.toList();
  final next = collapseDuplicateChannels([
    for (final platform in current)
      _applyListingToExisting(
        platform,
        _listingForPlatform(discovered, platform),
        now,
      ),
  ]);
  for (final listing in discovered) {
    final name = listing.displayName.trim();
    if (name.isEmpty) {
      continue;
    }
    if (next.any((platform) => _sameChannel(platform, listing))) {
      continue;
    }
    next.add(_platformFromListing(listing, now));
  }
  return collapseDuplicateChannels(next);
}

/// Adds TMDb listings using the same live/not-live rules as Check Status.
List<PlatformStatus> addDiscoveredWaitingPlatforms({
  required List<PlatformStatus> current,
  required Iterable<DiscoveredAvailability> listings,
  DateTime? checkedAt,
}) {
  return applyDiscoveredPlatforms(
    current: current,
    listings: listings,
    checkedAt: checkedAt,
  );
}

DiscoveredAvailability? _listingForPlatform(
  List<DiscoveredAvailability> listings,
  PlatformStatus platform,
) {
  for (final listing in listings) {
    if (_sameChannel(platform, listing)) {
      return listing;
    }
  }
  return null;
}

bool _sameChannel(PlatformStatus platform, DiscoveredAvailability listing) {
  return PlatformAliases.sameChannel(
    leftName: platform.platformName,
    leftUrl: platform.evidenceUrl,
    leftProviderId: platform.sourceProviderId,
    rightName: listing.displayName,
    rightUrl: listing.listingUrl,
    rightProviderId: listing.sourceProviderId,
  );
}

/// TMDb's listing is the real channel. A manual row is only a holder.
PlatformStatus adoptDiscoveredListing(
  PlatformStatus platform,
  DiscoveredAvailability listing,
) {
  final name = listing.displayName.trim();
  return platform.copyWith(
    platformName: name.isEmpty ? platform.platformName : name,
    origin: PlatformOrigin.automatic,
    licenseRelationship: LicenseRelationship.unknown,
  );
}

List<PlatformStatus> collapseDuplicateChannels(List<PlatformStatus> platforms) {
  final kept = <PlatformStatus>[];
  for (final platform in platforms) {
    final index = kept.indexWhere(
      (existing) => PlatformAliases.sameChannel(
        leftName: existing.platformName,
        leftUrl: existing.evidenceUrl,
        leftProviderId: existing.sourceProviderId,
        rightName: platform.platformName,
        rightUrl: platform.evidenceUrl,
        rightProviderId: platform.sourceProviderId,
      ),
    );
    if (index < 0) {
      kept.add(platform);
      continue;
    }
    kept[index] = _preferChannel(kept[index], platform);
  }
  return kept;
}

PlatformStatus _preferChannel(PlatformStatus left, PlatformStatus right) {
  final primary = _channelRank(right) > _channelRank(left) ? right : left;
  final secondary = identical(primary, right) ? left : right;
  final firstDetected = _earlierDate(
    primary.firstDetectedAt,
    secondary.firstDetectedAt,
  );
  return primary.copyWith(
    firstDetectedAt: firstDetected,
    firstDetectedLabel: firstDetected == null
        ? primary.firstDetectedLabel ?? secondary.firstDetectedLabel
        : formatMonitoringTimestamp(firstDetected),
    sourceProviderId: primary.sourceProviderId ?? secondary.sourceProviderId,
    evidenceUrl: PlatformAliases.preferSpecificListingUrl(
      primary.evidenceUrl,
      secondary.evidenceUrl,
    ),
    history: primary.history.length >= secondary.history.length
        ? primary.history
        : secondary.history,
  );
}

int _channelRank(PlatformStatus platform) {
  switch (platform.status) {
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

DateTime? _earlierDate(DateTime? left, DateTime? right) {
  if (left == null) {
    return right;
  }
  if (right == null) {
    return left;
  }
  return left.isBefore(right) ? left : right;
}

PlatformStatus _applyListingToExisting(
  PlatformStatus platform,
  DiscoveredAvailability? listing,
  DateTime checkedAt,
) {
  if (listing == null) {
    return platform;
  }
  if (listing.countsAsLiveEvidence) {
    return applyMonitoringResult(
      adoptDiscoveredListing(platform, listing),
      _liveResultFromListing(listing, checkedAt),
    ).copyWith(
      sourceProviderId: listing.sourceProviderId ?? platform.sourceProviderId,
      evidenceUrl: PlatformAliases.preferSpecificListingUrl(
        platform.evidenceUrl,
        listing.listingUrl,
      ),
    );
  }
  if (platform.isUserConfirmedAvailability) {
    return adoptDiscoveredListing(platform, listing).copyWith(
      lastCheckedAt: checkedAt,
      lastCheckedLabel: formatMonitoringTimestamp(checkedAt),
      sourceProviderId: listing.sourceProviderId ?? platform.sourceProviderId,
    );
  }
  final adopted = adoptDiscoveredListing(platform, listing);
  return withAutomatedStatusHistory(
    current: adopted,
    next: adopted.copyWith(
      status: DistributionStatus.originalNetwork,
      lastCheckedAt: checkedAt,
      lastCheckedLabel: formatMonitoringTimestamp(checkedAt),
      statusMessage: 'Original network',
      statusDetail: listing.detail,
      lastMonitoringSource: listing.sourceName,
      lastMatchConfidence: MatchConfidence.verifiedMatch,
      sourceProviderId: listing.sourceProviderId ?? platform.sourceProviderId,
    ),
    timestamp: checkedAt,
    sourceName: listing.sourceName,
    reason: listing.detail ?? 'Listed as the original network.',
  );
}

PlatformStatus _platformFromListing(
  DiscoveredAvailability listing,
  DateTime checkedAt,
) {
  final waiting = PlatformStatus.waiting(
    listing.displayName,
    origin: PlatformOrigin.automatic,
    licenseRelationship: LicenseRelationship.unknown,
  );
  if (!listing.countsAsLiveEvidence) {
    return withAutomatedStatusHistory(
      current: waiting,
      next: waiting.copyWith(
        status: DistributionStatus.originalNetwork,
        lastCheckedAt: checkedAt,
        lastCheckedLabel: formatMonitoringTimestamp(checkedAt),
        statusMessage: 'Original network',
        statusDetail: listing.detail,
        lastMonitoringSource: listing.sourceName,
        lastMatchConfidence: MatchConfidence.verifiedMatch,
        sourceProviderId: listing.sourceProviderId,
      ),
      timestamp: checkedAt,
      sourceName: listing.sourceName,
      reason: listing.detail ?? 'Listed as the original network.',
    );
  }
  return applyMonitoringResult(
    waiting,
    _liveResultFromListing(listing, checkedAt),
  ).copyWith(sourceProviderId: listing.sourceProviderId);
}

MonitoringResult _liveResultFromListing(
  DiscoveredAvailability listing,
  DateTime checkedAt,
) {
  return MonitoringResult.verifiedLive(
    platformName: listing.displayName,
    checkedAt: checkedAt,
    evidenceSource: listing.sourceName,
    evidenceUrl: listing.listingUrl,
    sourceName: listing.sourceName,
    detail: listing.detail ?? 'Listed as ${listing.displayName}.',
  );
}

String? tmdbPosterUrl(String? posterPath) {
  final path = posterPath?.trim() ?? '';
  if (path.isEmpty) {
    return null;
  }
  final normalized = path.startsWith('/') ? path : '/$path';
  return 'https://image.tmdb.org/t/p/w500$normalized';
}

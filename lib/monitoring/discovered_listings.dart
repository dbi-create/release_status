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
      (licensed) => PlatformAliases.referToSameService(licensed, name),
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
  final next = <PlatformStatus>[
    for (final platform in current)
      _applyListingToExisting(
        platform,
        _listingForPlatform(discovered, platform.platformName),
        now,
      ),
  ];
  for (final listing in discovered) {
    final name = listing.displayName.trim();
    if (name.isEmpty) {
      continue;
    }
    if (next.any(
      (platform) =>
          PlatformAliases.referToSameService(platform.platformName, name),
    )) {
      continue;
    }
    next.add(_platformFromListing(listing, now));
  }
  return next;
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
  String platformName,
) {
  for (final listing in listings) {
    if (PlatformAliases.referToSameService(platformName, listing.displayName)) {
      return listing;
    }
  }
  return null;
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
      platform,
      _liveResultFromListing(listing, checkedAt),
    ).copyWith(
      sourceProviderId: listing.sourceProviderId ?? platform.sourceProviderId,
    );
  }
  if (platform.isUserConfirmedAvailability) {
    return platform.copyWith(
      lastCheckedAt: checkedAt,
      lastCheckedLabel: formatMonitoringTimestamp(checkedAt),
      sourceProviderId: listing.sourceProviderId ?? platform.sourceProviderId,
    );
  }
  return withAutomatedStatusHistory(
    current: platform,
    next: platform.copyWith(
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

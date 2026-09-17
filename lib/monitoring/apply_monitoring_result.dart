import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/platform_status_event.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/removal_policy.dart';

String formatMonitoringTimestamp(DateTime value) =>
    formatStoredTimestamp(value);

PlatformStatus applyMonitoringResult(
  PlatformStatus current,
  MonitoringResult result, {
  RemovalConfirmationPolicy removalPolicy = RemovalConfirmationPolicy.standard,
}) {
  final checkedLabel = result.checkedAt == null
      ? current.lastCheckedLabel
      : formatMonitoringTimestamp(result.checkedAt!);
  final sourceName = result.sourceName ?? result.evidenceSource;

  if (result.checkFailed) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'Could not complete this check',
      statusDetail: result.detail ?? result.message,
      lastMonitoringSource: current.isUserConfirmedAvailability
          ? current.lastMonitoringSource
          : sourceName ?? current.lastMonitoringSource,
      lastMatchConfidence: result.matchConfidence,
      lastCheckFailed: true,
    );
  }

  if (result.isVerifiedLive) {
    return _withOptionalHistory(
      current: current,
      next: current.copyWith(
        status: DistributionStatus.live,
        firstDetectedLabel:
            current.firstDetectedLabel ??
            (result.checkedAt == null
                ? null
                : formatMonitoringTimestamp(result.checkedAt!)),
        firstDetectedAt: current.firstDetectedAt ?? result.checkedAt,
        lastCheckedAt: result.checkedAt,
        lastCheckedLabel: checkedLabel,
        statusMessage: 'Detected on ${current.platformName}',
        statusDetail: result.detail,
        evidenceSource: result.evidenceSource,
        evidenceUrl: result.evidenceUrl,
        lastMonitoringSource: sourceName,
        lastMatchConfidence: MatchConfidence.verifiedMatch,
        lastCheckFailed: false,
        consecutiveVerifiedAbsences: 0,
        clearRemovedAt: true,
      ),
      result: result,
      sourceName: sourceName,
      reason: result.detail ?? 'Verified public availability.',
    );
  }

  if (current.isUserConfirmedAvailability) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusDetail:
          'Public listings still do not show this platform. Your confirmation is unchanged.',
      lastMatchConfidence: result.matchConfidence,
      lastCheckFailed: false,
    );
  }

  if (result.matchConfidence == MatchConfidence.possibleMatch) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'This title could not be confidently matched',
      statusDetail:
          result.detail ??
          'A similar title was found, but identity was not unique enough to verify.',
      lastMonitoringSource: sourceName ?? current.lastMonitoringSource,
      lastMatchConfidence: MatchConfidence.possibleMatch,
      lastCheckFailed: false,
    );
  }

  if (result.isVerifiedAbsence) {
    return _applyVerifiedAbsence(
      current: current,
      result: result,
      checkedLabel: checkedLabel,
      sourceName: sourceName,
      removalPolicy: removalPolicy,
    );
  }

  return current.copyWith(
    lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
    lastCheckedLabel: checkedLabel,
    statusMessage: result.message,
    statusDetail: result.detail,
    lastMonitoringSource: sourceName ?? current.lastMonitoringSource,
    lastMatchConfidence: result.matchConfidence,
    lastCheckFailed: false,
  );
}

PlatformStatus _applyVerifiedAbsence({
  required PlatformStatus current,
  required MonitoringResult result,
  required String? checkedLabel,
  required String? sourceName,
  required RemovalConfirmationPolicy removalPolicy,
}) {
  if (current.status != DistributionStatus.live &&
      current.status != DistributionStatus.removed) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'Not detected yet',
      statusDetail:
          result.detail ??
          'The title was identified, but this platform was not listed.',
      lastMonitoringSource: sourceName ?? current.lastMonitoringSource,
      lastMatchConfidence: MatchConfidence.verifiedMatch,
      lastCheckFailed: false,
      consecutiveVerifiedAbsences: 0,
    );
  }

  if (current.status == DistributionStatus.removed) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'Previously detected, no longer found',
      statusDetail: result.detail,
      lastMonitoringSource: sourceName ?? current.lastMonitoringSource,
      lastMatchConfidence: MatchConfidence.verifiedMatch,
      lastCheckFailed: false,
    );
  }

  final consecutive = current.consecutiveVerifiedAbsences + 1;
  if (!removalPolicy.confirmsRemoval(consecutive)) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'Detected on ${current.platformName}',
      statusDetail:
          'Still marked live. Public listings have not shown this platform '
          '$consecutive of ${removalPolicy.requiredConsecutiveVerifiedAbsences} '
          'confirmed checks.',
      lastMonitoringSource: sourceName ?? current.lastMonitoringSource,
      lastMatchConfidence: MatchConfidence.verifiedMatch,
      lastCheckFailed: false,
      consecutiveVerifiedAbsences: consecutive,
    );
  }

  return _withOptionalHistory(
    current: current,
    next: current.copyWith(
      status: DistributionStatus.removed,
      lastCheckedAt: result.checkedAt,
      lastCheckedLabel: checkedLabel,
      removedAt: result.checkedAt ?? DateTime.now(),
      statusMessage: 'Previously detected, no longer found',
      statusDetail: result.detail,
      lastMonitoringSource: sourceName,
      lastMatchConfidence: MatchConfidence.verifiedMatch,
      lastCheckFailed: false,
      consecutiveVerifiedAbsences: consecutive,
    ),
    result: result,
    sourceName: sourceName,
    reason:
        result.detail ??
        'Confirmed absent on ${removalPolicy.requiredConsecutiveVerifiedAbsences} consecutive verified checks.',
  );
}

PlatformStatus _withOptionalHistory({
  required PlatformStatus current,
  required PlatformStatus next,
  required MonitoringResult result,
  required String? sourceName,
  required String reason,
}) {
  if (current.status == next.status) {
    return next;
  }
  final event = PlatformStatusEvent(
    previousStatus: current.status,
    newStatus: next.status,
    timestamp: result.checkedAt ?? DateTime.now(),
    sourceName: sourceName ?? 'Availability check',
    reason: reason,
    fromAutomatedCheck: true,
  );
  return next.copyWith(history: [...current.history, event]);
}

PlatformStatus withAutomatedStatusHistory({
  required PlatformStatus current,
  required PlatformStatus next,
  required DateTime timestamp,
  required String sourceName,
  required String reason,
}) {
  if (current.status == next.status) {
    return next;
  }
  return next.copyWith(
    history: [
      ...current.history,
      PlatformStatusEvent(
        previousStatus: current.status,
        newStatus: next.status,
        timestamp: timestamp,
        sourceName: sourceName,
        reason: reason,
        fromAutomatedCheck: true,
      ),
    ],
  );
}

PlatformStatus applyUserConfirmedLive(
  PlatformStatus current, {
  required DateTime confirmedAt,
  String? listingUrl,
}) {
  final trimmedUrl = listingUrl?.trim() ?? '';
  final nextUrl = trimmedUrl.isEmpty ? current.evidenceUrl : trimmedUrl;
  final checkedLabel = formatMonitoringTimestamp(confirmedAt);
  final next = current.copyWith(
    status: DistributionStatus.live,
    firstDetectedLabel: current.firstDetectedLabel ?? checkedLabel,
    firstDetectedAt: current.firstDetectedAt ?? confirmedAt,
    lastCheckedAt: confirmedAt,
    lastCheckedLabel: checkedLabel,
    statusMessage: 'You confirmed this is live on ${current.platformName}',
    statusDetail:
        'This is your confirmation, not an independent public listing.',
    evidenceSource: userConfirmedAvailabilitySource,
    evidenceUrl: nextUrl,
    lastMonitoringSource: userConfirmedAvailabilitySource,
    lastCheckFailed: false,
    consecutiveVerifiedAbsences: 0,
    clearRemovedAt: true,
  );
  if (current.status == DistributionStatus.live) {
    return next;
  }
  return next.copyWith(
    history: [
      ...current.history,
      PlatformStatusEvent(
        previousStatus: current.status,
        newStatus: DistributionStatus.live,
        timestamp: confirmedAt,
        sourceName: userConfirmedAvailabilitySource,
        reason: 'You confirmed this title is currently available.',
        fromAutomatedCheck: false,
      ),
    ],
  );
}

/// Marks a manual platform live after a user-pasted listing URL checked out.
///
/// This is not TMDb evidence. Failed URL checks must not call this.
PlatformStatus applyVerifiedListingLive(
  PlatformStatus current, {
  required DateTime checkedAt,
  required String listingUrl,
}) {
  final checkedLabel = formatMonitoringTimestamp(checkedAt);
  final next = current.copyWith(
    status: DistributionStatus.live,
    firstDetectedLabel: current.firstDetectedLabel ?? checkedLabel,
    firstDetectedAt: current.firstDetectedAt ?? checkedAt,
    lastCheckedAt: checkedAt,
    lastCheckedLabel: checkedLabel,
    statusMessage: 'Listed at a public URL you provided',
    statusDetail:
        'The listing page is reachable and mentions this title. This is not a TMDb watch-provider listing.',
    evidenceSource: listingUrlAvailabilitySource,
    evidenceUrl: listingUrl,
    lastMonitoringSource: listingUrlAvailabilitySource,
    lastCheckFailed: false,
    consecutiveVerifiedAbsences: 0,
    clearRemovedAt: true,
  );
  if (current.status == DistributionStatus.live) {
    return next;
  }
  return next.copyWith(
    history: [
      ...current.history,
      PlatformStatusEvent(
        previousStatus: current.status,
        newStatus: DistributionStatus.live,
        timestamp: checkedAt,
        sourceName: listingUrlAvailabilitySource,
        reason: 'The listing page mentioned this title.',
        fromAutomatedCheck: true,
      ),
    ],
  );
}

/// Undoes a user confirmation. Returns the platform to waiting. Does not
/// invent REMOVED from TMDb and does not keep a false LIVE mark.
PlatformStatus applyClearUserConfirmedLive(
  PlatformStatus current, {
  required DateTime clearedAt,
}) {
  if (!current.isUserConfirmedAvailability) {
    return current;
  }
  final checkedLabel = formatMonitoringTimestamp(clearedAt);
  return PlatformStatus(
    platformName: current.platformName,
    status: DistributionStatus.waiting,
    lastCheckedLabel: checkedLabel,
    lastCheckedAt: clearedAt,
    statusMessage: 'Not detected yet',
    statusDetail: 'You removed live status for this platform.',
    history: [
      ...current.history,
      PlatformStatusEvent(
        previousStatus: current.status,
        newStatus: DistributionStatus.waiting,
        timestamp: clearedAt,
        sourceName: userConfirmedAvailabilitySource,
        reason: 'You removed live status.',
        fromAutomatedCheck: false,
      ),
    ],
    origin: current.origin,
    licenseRelationship: current.licenseRelationship,
    sourceProviderId: current.sourceProviderId,
  );
}

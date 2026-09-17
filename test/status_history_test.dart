import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/removal_policy.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_matcher.dart';

void main() {
  final checkedAt = DateTime(2026, 9, 14, 18);

  MonitoringResult live(String platform) {
    return MonitoringResult.verifiedLive(
      platformName: platform,
      checkedAt: checkedAt,
      evidenceSource: 'TMDb Watch Providers',
    );
  }

  MonitoringResult absence(String platform) {
    return MonitoringResult.verifiedAbsence(
      platformName: platform,
      checkedAt: checkedAt,
      evidenceSource: 'TMDb Watch Providers',
      detail: 'Not listed',
    );
  }

  group('status history', () {
    test('WAITING → LIVE creates one history event', () {
      final updated = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      expect(updated.status, DistributionStatus.live);
      expect(updated.history, hasLength(1));
      expect(updated.history.single.previousStatus, DistributionStatus.waiting);
      expect(updated.history.single.newStatus, DistributionStatus.live);
      expect(updated.history.single.fromAutomatedCheck, isTrue);
    });

    test('unchanged LIVE does not duplicate history', () {
      final first = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      final second = applyMonitoringResult(first, live('Netflix'));
      expect(second.status, DistributionStatus.live);
      expect(second.history, hasLength(1));
    });

    test('LIVE → REMOVED after confirmed verified absences', () {
      var platform = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      const policy = RemovalConfirmationPolicy(
        requiredConsecutiveVerifiedAbsences: 3,
      );
      platform = applyMonitoringResult(
        platform,
        absence('Netflix'),
        removalPolicy: policy,
      );
      expect(platform.status, DistributionStatus.live);
      expect(platform.history, hasLength(1));
      platform = applyMonitoringResult(
        platform,
        absence('Netflix'),
        removalPolicy: policy,
      );
      expect(platform.status, DistributionStatus.live);
      platform = applyMonitoringResult(
        platform,
        absence('Netflix'),
        removalPolicy: policy,
      );
      expect(platform.status, DistributionStatus.removed);
      expect(platform.history, hasLength(2));
      expect(platform.history.last.previousStatus, DistributionStatus.live);
      expect(platform.history.last.newStatus, DistributionStatus.removed);
      expect(platform.statusMessage, 'Previously detected, no longer found');
    });

    test('REMOVED → LIVE creates a history event', () {
      const policy = RemovalConfirmationPolicy(
        requiredConsecutiveVerifiedAbsences: 1,
      );
      var platform = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      platform = applyMonitoringResult(
        platform,
        absence('Netflix'),
        removalPolicy: policy,
      );
      expect(platform.status, DistributionStatus.removed);
      platform = applyMonitoringResult(platform, live('Netflix'));
      expect(platform.status, DistributionStatus.live);
      expect(platform.history.last.previousStatus, DistributionStatus.removed);
      expect(platform.history.last.newStatus, DistributionStatus.live);
    });
  });

  group('removal safety', () {
    test('a single verified absence does not remove', () {
      var platform = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      platform = applyMonitoringResult(platform, absence('Netflix'));
      expect(platform.status, DistributionStatus.live);
      expect(platform.consecutiveVerifiedAbsences, 1);
    });

    test('failed checks do not cause REMOVED', () {
      var platform = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      platform = applyMonitoringResult(
        platform,
        MonitoringResult.failed(
          platformName: 'Netflix',
          checkedAt: checkedAt,
          detail: 'Could not reach the availability source.',
        ),
      );
      expect(platform.status, DistributionStatus.live);
      expect(platform.lastCheckFailed, isTrue);
      expect(platform.consecutiveVerifiedAbsences, 0);
    });

    test('possible match does not count as verified absence', () {
      var platform = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      platform = applyMonitoringResult(
        platform,
        MonitoringResult.notVerified(
          platformName: 'Netflix',
          checkedAt: checkedAt,
          matchConfidence: MatchConfidence.possibleMatch,
        ),
      );
      expect(platform.status, DistributionStatus.live);
      expect(platform.consecutiveVerifiedAbsences, 0);
    });

    test('title-only no-match does not remove a LIVE platform', () {
      var platform = applyMonitoringResult(
        PlatformStatus.waiting('Netflix'),
        live('Netflix'),
      );
      platform = applyMonitoringResult(
        platform,
        MonitoringResult.notVerified(
          platformName: 'Netflix',
          checkedAt: checkedAt,
        ),
      );
      expect(platform.status, DistributionStatus.live);
      expect(platform.consecutiveVerifiedAbsences, 0);
    });

    test('threshold is centralized', () {
      expect(
        RemovalConfirmationPolicy.standard.requiredConsecutiveVerifiedAbsences,
        RemovalConfirmationPolicy.defaultRequiredConsecutiveVerifiedAbsences,
      );
      expect(
        RemovalConfirmationPolicy.defaultRequiredConsecutiveVerifiedAbsences,
        3,
      );
    });
  });

  group('identity cannot create LIVE', () {
    test('name-only match is not verified', () {
      expect(
        classifyTitleMatch(
          query: const TitleIdentity(
            title: 'MARKED',
            contentType: 'TV Series',
            releaseYear: 2026,
          ),
          candidate: const TitleCandidate(
            name: 'MARKED',
            year: null,
            contentType: 'TV Series',
          ),
        ),
        MatchConfidence.possibleMatch,
      );
    });

    test('possible match cannot become LIVE', () {
      final updated = applyMonitoringResult(
        PlatformStatus.waiting('Relay'),
        MonitoringResult(
          platformName: 'Relay',
          status: DistributionStatus.live,
          matchConfidence: MatchConfidence.possibleMatch,
          message: 'Should not apply',
          evidenceSource: 'TMDb Watch Providers',
          checkedAt: checkedAt,
        ),
      );
      expect(updated.status, DistributionStatus.waiting);
      expect(updated.history, isEmpty);
    });

    test('title-only live proposal cannot become LIVE', () {
      final updated = applyMonitoringResult(
        PlatformStatus.waiting('Relay'),
        MonitoringResult(
          platformName: 'Relay',
          status: DistributionStatus.live,
          matchConfidence: MatchConfidence.noMatch,
          message: 'Should not apply',
          evidenceSource: 'TMDb Watch Providers',
          checkedAt: checkedAt,
        ),
      );
      expect(updated.status, DistributionStatus.waiting);
    });
  });
}

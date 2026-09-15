import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/monitoring_result.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatMonitoringTimestamp(DateTime value) {
  final local = value.toLocal();
  final month = _months[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} $month ${local.year}, $hour:$minute';
}

PlatformStatus applyMonitoringResult(
  PlatformStatus current,
  MonitoringResult result,
) {
  final checkedLabel = result.checkedAt == null
      ? current.lastCheckedLabel
      : formatMonitoringTimestamp(result.checkedAt!);

  if (result.checkFailed) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'Check failed',
      statusDetail: result.detail ?? result.message,
      lastCheckFailed: true,
    );
  }

  if (result.isVerifiedLive) {
    return current.copyWith(
      status: DistributionStatus.live,
      firstDetectedLabel:
          current.firstDetectedLabel ??
          (result.checkedAt == null
              ? null
              : formatMonitoringTimestamp(result.checkedAt!)),
      lastCheckedAt: result.checkedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'Verified availability',
      statusDetail: result.detail,
      evidenceSource: result.evidenceSource,
      evidenceUrl: result.evidenceUrl,
      lastCheckFailed: false,
    );
  }

  if (result.matchConfidence == MatchConfidence.possibleMatch) {
    return current.copyWith(
      lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: 'Possible match — verification required',
      statusDetail: result.detail,
      lastCheckFailed: false,
    );
  }

  if (current.status == DistributionStatus.live &&
      result.matchConfidence == MatchConfidence.verifiedMatch &&
      result.status == DistributionStatus.removed) {
    return current.copyWith(
      status: DistributionStatus.removed,
      lastCheckedAt: result.checkedAt,
      lastCheckedLabel: checkedLabel,
      statusMessage: result.message,
      statusDetail: result.detail,
      lastCheckFailed: false,
    );
  }

  return current.copyWith(
    lastCheckedAt: result.checkedAt ?? current.lastCheckedAt,
    lastCheckedLabel: checkedLabel,
    statusMessage: result.message,
    statusDetail: result.detail,
    lastCheckFailed: false,
  );
}

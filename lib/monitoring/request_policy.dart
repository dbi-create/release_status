/// Delay between sequential availability requests.
///
/// Check All Titles must not fire aggressive parallel traffic.
class MonitoringRequestPolicy {
  const MonitoringRequestPolicy({
    this.delayBetweenRequests = defaultDelayBetweenRequests,
  });

  static const Duration defaultDelayBetweenRequests = Duration(
    milliseconds: 250,
  );

  static const MonitoringRequestPolicy standard = MonitoringRequestPolicy();

  static const MonitoringRequestPolicy immediate = MonitoringRequestPolicy(
    delayBetweenRequests: Duration.zero,
  );

  final Duration delayBetweenRequests;
}

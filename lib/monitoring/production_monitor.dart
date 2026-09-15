import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/tmdb_availability_monitor.dart';

/// Default production monitor: TMDb when a compile-time key is present,
/// otherwise a truthful unconfigured monitor that performs no lookup.
AvailabilityMonitor createProductionAvailabilityMonitor() {
  const apiKey = String.fromEnvironment('TMDB_API_KEY');
  if (apiKey.isEmpty) {
    return const UnconfiguredAvailabilityMonitor();
  }
  return TmdbAvailabilityMonitor(apiKey: apiKey);
}

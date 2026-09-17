import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/composite_monitor.dart';
import 'package:release_status/monitoring/tmdb_availability_monitor.dart';

/// Default production monitor: TMDb when a compile-time key is present,
/// otherwise a truthful unconfigured monitor that performs no lookup.
///
/// Additional sources can be appended to the composite later. Do not store
/// API keys in this file.
AvailabilityMonitor createProductionAvailabilityMonitor() {
  const apiKey = String.fromEnvironment('TMDB_API_KEY');
  final tmdb = apiKey.isEmpty
      ? const UnconfiguredAvailabilityMonitor()
      : TmdbAvailabilityMonitor(apiKey: apiKey);
  return CompositeAvailabilityMonitor([tmdb]);
}

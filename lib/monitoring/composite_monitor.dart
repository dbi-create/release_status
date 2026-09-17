import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/discovery_monitor.dart';
import 'package:release_status/monitoring/discovery_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_lookup.dart';

/// Provider-neutral fan-in for multiple availability sources.
///
/// TMDb is source #1. Later sources (JustWatch, Watchmode, a ReleaseStatus
/// backend, and permitted platform APIs) can be appended without changing
/// screens or the title catalog.
class CompositeAvailabilityMonitor
    implements AvailabilityMonitor, DiscoveryMonitor, TitleLookup {
  const CompositeAvailabilityMonitor(this.sources);

  final List<AvailabilityMonitor> sources;

  Iterable<AvailabilityMonitor> get configuredSources =>
      sources.where((source) => source.isConfigured);

  @override
  String get sourceId => 'composite';

  @override
  String get displayName {
    final configured = configuredSources.toList(growable: false);
    if (configured.isEmpty) {
      return 'Not configured';
    }
    if (configured.length == 1) {
      return configured.first.displayName;
    }
    return 'Combined availability sources';
  }

  @override
  bool get isConfigured => configuredSources.isNotEmpty;

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    for (final source in sources) {
      if (!source.isConfigured) {
        continue;
      }
      return source.check(title: title, licensedPlatform: licensedPlatform);
    }
    return MonitoringResult.unconfigured(licensedPlatform);
  }

  @override
  Future<DiscoveryResult> discover({required TitleIdentity title}) async {
    DiscoveryResult? lastFailed;
    for (final source in sources) {
      if (!source.isConfigured || source is! DiscoveryMonitor) {
        continue;
      }
      final discoverySource = source as DiscoveryMonitor;
      final result = await discoverySource.discover(title: title);
      if (!result.failed) {
        return result;
      }
      lastFailed = result;
    }
    return lastFailed ?? DiscoveryResult.unconfigured();
  }

  @override
  Future<List<TitleLookupMatch>> searchByName({
    required String name,
    String? contentType,
    int? year,
  }) async {
    for (final source in sources) {
      if (!source.isConfigured || source is! TitleLookup) {
        continue;
      }
      final lookup = source as TitleLookup;
      return lookup.searchByName(
        name: name,
        contentType: contentType,
        year: year,
      );
    }
    return const [];
  }
}

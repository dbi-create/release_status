import 'package:release_status/monitoring/discovery_result.dart';
import 'package:release_status/monitoring/title_identity.dart';

/// Provider-neutral discovery of every verified platform for a title.
///
/// TMDb is the first implementation. JustWatch, Watchmode, Reelgood, permitted
/// platform APIs, and a future ReleaseStatus backend can implement this
/// without changing TitleCatalog or the UI.
abstract class DiscoveryMonitor {
  Future<DiscoveryResult> discover({required TitleIdentity title});
}

import 'package:release_status/cloud/cloud_catalog_sync.dart';
import 'package:release_status/cloud/cloud_session.dart';
import 'package:release_status/state/title_catalog.dart';

/// Attach the signed-in user to this device catalog.
/// Cloud titles win if they exist; otherwise this device is uploaded.
Future<void> attachSignedInCatalog(TitleCatalog catalog) async {
  final client = releaseStatusCloudClient();
  if (client == null || client.auth.currentUser == null) {
    return;
  }
  await catalog.cloudSync?.stopWatching();
  catalog.cloudSync = CloudCatalogSync(client);
  await catalog.persistCompleted;
  final epoch = catalog.syncRevision;
  final remote = await catalog.cloudSync!.pull();
  if (remote != null && remote.titles.isNotEmpty) {
    catalog.applyCloudSnapshot(remote, pullEpoch: epoch);
  } else {
    await catalog.syncToCloud();
  }
  await catalog.cloudSync?.watch(catalog.syncFromCloud);
}

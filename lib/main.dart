import 'package:flutter/material.dart';

import 'package:release_status/app.dart';
import 'package:release_status/cloud/cloud_session.dart';
import 'package:release_status/storage/catalog_codec.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeReleaseStatusCloud();
  final store = JsonFileCatalogStore();
  final snapshot = await store.load();
  runApp(
    ReleaseStatusApp(
      catalogStore: store,
      initialSnapshot: snapshot,
      enableScheduledMonitoring: true,
      showBootSplash: true,
    ),
  );
}

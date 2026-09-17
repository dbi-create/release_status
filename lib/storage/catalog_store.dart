import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/release_title.dart';

/// Durable catalog snapshot. A future cloud backend can replace the store
/// implementation without changing screens.
class CatalogSnapshot {
  const CatalogSnapshot({
    required this.titles,
    required this.createdCount,
    required this.settings,
    this.existedOnDisk = false,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  factory CatalogSnapshot.empty() {
    return const CatalogSnapshot(
      titles: [],
      createdCount: 0,
      settings: AppSettings(),
      existedOnDisk: false,
    );
  }

  final List<ReleaseTitle> titles;
  final int createdCount;
  final AppSettings settings;
  final bool existedOnDisk;
  final int schemaVersion;

  CatalogSnapshot copyWith({
    List<ReleaseTitle>? titles,
    int? createdCount,
    AppSettings? settings,
    bool? existedOnDisk,
    int? schemaVersion,
  }) {
    return CatalogSnapshot(
      titles: titles ?? this.titles,
      createdCount: createdCount ?? this.createdCount,
      settings: settings ?? this.settings,
      existedOnDisk: existedOnDisk ?? this.existedOnDisk,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}

/// Persistence boundary. Screens must not call this directly.
abstract class CatalogStore {
  Future<CatalogSnapshot> load();

  Future<void> save(CatalogSnapshot snapshot);
}

/// In-memory store for tests and session-only widget trees.
class MemoryCatalogStore implements CatalogStore {
  MemoryCatalogStore({CatalogSnapshot? initial}) : _snapshot = initial;

  CatalogSnapshot? _snapshot;

  @override
  Future<CatalogSnapshot> load() async {
    return _snapshot ?? CatalogSnapshot.empty();
  }

  @override
  Future<void> save(CatalogSnapshot snapshot) async {
    _snapshot = snapshot.copyWith(existedOnDisk: true);
  }
}

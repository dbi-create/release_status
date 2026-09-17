import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:release_status/cloud/cloud_catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';

class CloudCatalogSync {
  CloudCatalogSync(this._client);

  final SupabaseClient _client;

  String? get userId => _client.auth.currentUser?.id;

  bool get isSignedIn => userId != null;

  Future<CatalogSnapshot?> pull() async {
    final uid = userId;
    if (uid == null) {
      return null;
    }
    final profile = await _client
        .from('release_status_profiles')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    final titles = await _client
        .from('release_status_titles')
        .select()
        .eq('owner_user_id', uid);
    final platforms = await _client
        .from('release_status_platforms')
        .select()
        .eq('owner_user_id', uid);
    final titleRows = _maps(titles);
    if (titleRows.isEmpty && profile == null) {
      return null;
    }
    return catalogSnapshotFromCloudRows(
      profile: profile == null ? null : Map<String, Object?>.from(profile),
      titles: titleRows,
      platforms: _maps(platforms),
    );
  }

  Future<void> push(CatalogSnapshot snapshot) async {
    final uid = userId;
    if (uid == null) {
      return;
    }
    await _client.from('release_status_profiles').upsert(
      profileRowFromSnapshot(userId: uid, snapshot: snapshot),
    );
    final titleRows = [
      for (final title in snapshot.titles)
        titleRowFromReleaseTitle(userId: uid, title: title),
    ];
    if (titleRows.isNotEmpty) {
      await _client.from('release_status_titles').upsert(titleRows);
    }
    final platformRows = [
      for (final title in snapshot.titles)
        for (final platform in title.platforms)
          platformRowFromStatus(
            userId: uid,
            titleId: title.id,
            platform: platform,
          ),
    ];
    if (platformRows.isNotEmpty) {
      await _client
          .from('release_status_platforms')
          .upsert(
            platformRows,
            onConflict: 'owner_user_id,title_id,platform_name',
          );
    }
    final keepTitleIds = {for (final title in snapshot.titles) title.id};
    final keepPlatforms = {
      for (final title in snapshot.titles)
        for (final platform in title.platforms)
          '${title.id}|${platform.platformName}',
    };
    final existingPlatforms = _maps(
      await _client
          .from('release_status_platforms')
          .select('title_id, platform_name')
          .eq('owner_user_id', uid),
    );
    for (final row in existingPlatforms) {
      final titleId = row['title_id'] as String? ?? '';
      final platformName = row['platform_name'] as String? ?? '';
      if (keepPlatforms.contains('$titleId|$platformName')) {
        continue;
      }
      await _client
          .from('release_status_platforms')
          .delete()
          .eq('owner_user_id', uid)
          .eq('title_id', titleId)
          .eq('platform_name', platformName);
    }
    final existingTitles = _maps(
      await _client
          .from('release_status_titles')
          .select('id')
          .eq('owner_user_id', uid),
    );
    final goneTitleIds = [
      for (final row in existingTitles)
        if (!keepTitleIds.contains(row['id'] as String? ?? ''))
          row['id'] as String,
    ];
    if (goneTitleIds.isNotEmpty) {
      await _client
          .from('release_status_titles')
          .delete()
          .eq('owner_user_id', uid)
          .inFilter('id', goneTitleIds);
    }
    if (snapshot.titles.isEmpty) {
      await _client
          .from('release_status_titles')
          .delete()
          .eq('owner_user_id', uid);
    }
  }

  List<Map<String, Object?>> _maps(dynamic rows) {
    if (rows is! List) {
      return const [];
    }
    return [
      for (final row in rows)
        if (row is Map) Map<String, Object?>.from(row),
    ];
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:release_status/cloud/cloud_session.dart';

Future<void> upsertPushToken(String token) async {
  final client = releaseStatusCloudClient();
  final userId = client?.auth.currentUser?.id;
  if (client == null || userId == null || token.isEmpty) {
    return;
  }
  final row = {
    'owner_user_id': userId,
    'device_token': token,
    'platform': _platformName(),
  };
  try {
    final updated = await client
        .from('release_status_push_tokens')
        .update({'platform': _platformName()})
        .eq('owner_user_id', userId)
        .eq('device_token', token)
        .select('id');
    if (updated.isNotEmpty) {
      return;
    }
    await client.from('release_status_push_tokens').insert(row);
    return;
  } on PostgrestException catch (error) {
    if (error.code == '23505') {
      return;
    }
  } on Object {
    // Fall through to upsert.
  }
  try {
    await client.from('release_status_push_tokens').upsert(
      row,
      onConflict: 'owner_user_id,device_token',
      ignoreDuplicates: true,
    );
  } on PostgrestException catch (error) {
    if (error.code == '23505') {
      return;
    }
  } on Object {
    // Duplicate token or a missing session must not block alerts.
  }
}

String? _pendingApnsToken;

Future<void> rememberAndSavePushToken(String token) async {
  if (token.isEmpty) {
    return;
  }
  _pendingApnsToken = token;
  await upsertPushToken(token);
}

String? cachedPushToken() => _pendingApnsToken;

String _platformName() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.android:
      return 'android';
    default:
      return 'other';
  }
}

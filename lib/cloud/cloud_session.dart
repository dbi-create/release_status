import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:release_status/cloud/cloud_config.dart';

Future<void> initializeReleaseStatusCloud() async {
  if (!CloudConfig.isConfigured) {
    return;
  }
  try {
    if (Supabase.instance.isInitialized) {
      return;
    }
  } on AssertionError {
    // instance access asserts until initialize() has run.
  }
  await Supabase.initialize(
    url: CloudConfig.url,
    publishableKey: CloudConfig.anonKey,
  );
}

bool get isReleaseStatusCloudReady {
  if (!CloudConfig.isConfigured) {
    return false;
  }
  try {
    return Supabase.instance.isInitialized;
  } on AssertionError {
    return false;
  }
}

SupabaseClient? releaseStatusCloudClient() {
  if (!isReleaseStatusCloudReady) {
    return null;
  }
  return Supabase.instance.client;
}

/// Auth session for cloud backup. Local catalog still works when this is empty.
class CloudSession extends ChangeNotifier {
  CloudSession({this._client});

  SupabaseClient? _client;
  String? lastError;
  bool busy = false;

  bool get isConfigured => CloudConfig.isConfigured;

  bool get isReady => _client != null;

  User? get user => _client?.auth.currentUser;

  bool get isSignedIn => user != null;

  String? get userId => user?.id;

  String get signedInLabel {
    final current = user;
    if (current == null) {
      return '';
    }
    final email = current.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return 'Signed in';
  }

  StreamSubscription<AuthState>? _authSub;

  void attachClient(SupabaseClient? client) {
    _authSub?.cancel();
    _client = client;
    _authSub = client?.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> signOut() async {
    try {
      await runBusy(() async {
        await _client?.auth.signOut();
      });
    } on Object {
      // lastError already set
    }
  }

  Future<void> runBusy(Future<void> Function() action) async {
    lastError = null;
    busy = true;
    notifyListeners();
    try {
      await action();
    } on Object catch (error) {
      lastError = '$error';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

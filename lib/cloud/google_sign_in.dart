import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:release_status/cloud/cloud_config.dart';

bool get supportsNativeGoogleSignIn {
  if (kIsWeb) {
    return false;
  }
  if (CloudConfig.googleWebClientId.isEmpty) {
    return false;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return CloudConfig.googleIosClientId.isNotEmpty;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return true;
  }
  return false;
}

Future<void>? _googleInitialize;

Future<void> _ensureGoogleInitialized() {
  return _googleInitialize ??= GoogleSignIn.instance.initialize(
    serverClientId: CloudConfig.googleWebClientId,
    clientId: CloudConfig.googleIosClientId.isEmpty
        ? null
        : CloudConfig.googleIosClientId,
  );
}

Future<void> signInToReleaseStatusWithGoogle(SupabaseClient client) async {
  if (supportsNativeGoogleSignIn) {
    await _signInNative(client);
    return;
  }
  final launched = await client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: CloudConfig.authRedirectUrl,
  );
  if (!launched) {
    throw const AuthException('Could not open Google sign-in.');
  }
}

Future<void> _signInNative(SupabaseClient client) async {
  await _ensureGoogleInitialized();
  final googleSignIn = GoogleSignIn.instance;
  GoogleSignInAccount? googleUser;
  final lightweight = googleSignIn.attemptLightweightAuthentication();
  if (lightweight != null) {
    try {
      googleUser = await lightweight;
    } catch (_) {
      googleUser = null;
    }
  }
  var idToken = googleUser?.authentication.idToken;
  if (idToken == null || idToken.isEmpty) {
    googleUser = await googleSignIn.authenticate();
    idToken = googleUser.authentication.idToken;
  }
  if (idToken == null || idToken.isEmpty) {
    throw const AuthException('Google Sign In did not return an identity token.');
  }
  await client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
  );
}

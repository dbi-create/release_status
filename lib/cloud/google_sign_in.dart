import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:release_status/cloud/cloud_config.dart';

/// Native Google Sign-In on iOS/macOS/Android. No Safari or supabase.co pages.
bool get supportsNativeGoogleSignIn {
  if (kIsWeb) {
    return false;
  }
  if (CloudConfig.googleWebClientId.isEmpty) {
    return false;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return CloudConfig.googleIosClientId.isNotEmpty;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return true;
  }
  return false;
}

String googleSignInUserMessage(Object error) {
  if (error is AuthException) {
    return error.message;
  }
  if (error is GoogleSignInException) {
    final description = error.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    return 'Google Sign In was not completed.';
  }
  if (error is PlatformException) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'Google Sign In failed (${error.code}).';
  }
  return 'Could not sign in with Google.';
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
  if (!supportsNativeGoogleSignIn) {
    throw const AuthException(
      'Google Sign-In is not configured for this build.',
    );
  }
  await _signInNative(client);
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
  final usedCachedSession =
      googleUser != null && idToken != null && idToken.isNotEmpty;
  if (!usedCachedSession) {
    googleUser = await googleSignIn.authenticate();
    idToken = googleUser.authentication.idToken;
  }
  if (idToken == null || idToken.isEmpty) {
    throw const AuthException(
      'Google Sign In did not return an identity token.',
    );
  }
  try {
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  } on AuthException {
    if (!usedCachedSession) {
      rethrow;
    }
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    googleUser = await googleSignIn.authenticate();
    idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        'Google Sign In did not return an identity token.',
      );
    }
    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }
}

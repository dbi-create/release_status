import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> signInToReleaseStatusWithApple(SupabaseClient client) async {
  final rawNonce = client.auth.generateRawNonce();
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
  );
  final idToken = credential.identityToken;
  if (idToken == null || idToken.isEmpty) {
    throw const AuthException('Apple did not return an identity token.');
  }
  await client.auth.signInWithIdToken(
    provider: OAuthProvider.apple,
    idToken: idToken,
    nonce: rawNonce,
  );
  final givenName = credential.givenName?.trim();
  final familyName = credential.familyName?.trim();
  final fullName = [
    if (givenName != null && givenName.isNotEmpty) givenName,
    if (familyName != null && familyName.isNotEmpty) familyName,
  ].join(' ');
  if (fullName.isNotEmpty) {
    await client.auth.updateUser(UserAttributes(data: {'full_name': fullName}));
  }
}

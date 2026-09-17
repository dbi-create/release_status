/// Compile-time cloud config. Pass URL and anon key via dart-define, never commit them.
class CloudConfig {
  const CloudConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static const authRedirectUrl = 'com.orbium.releaseStatus://login-callback';
}

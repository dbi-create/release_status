/// Maps user-typed platform names to a canonical service id for matching.
///
/// This does not prove availability. It only helps compare a user's licensed
/// platform name with a provider's service name.
class PlatformAliases {
  static const Map<String, Set<String>> _aliases = {
    'amazon': {
      'amazon',
      'amazon prime',
      'amazon prime video',
      'amazon video',
      'prime video',
      'prime',
    },
    'plex': {'plex', 'plex tv'},
    'fawesome': {
      'fawesome',
      'future today',
      'future today fawesome',
      'future today (fawesome)',
    },
    'ofive_plus': {'ofive+', 'ofive plus', 'ofive', 'ofiveplus'},
    'relay': {'relay'},
  };

  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Canonical id for a known test platform, or null if unrecognized.
  static String? canonicalId(String platformName) {
    final normalized = normalize(platformName);
    for (final entry in _aliases.entries) {
      if (entry.value.any((alias) => normalize(alias) == normalized)) {
        return entry.key;
      }
    }
    return null;
  }

  /// True when two names refer to the same known service, or are equal
  /// after normalization if the service is not in the alias table.
  static bool referToSameService(String left, String right) {
    final leftId = canonicalId(left);
    final rightId = canonicalId(right);
    if (leftId != null && rightId != null) {
      return leftId == rightId;
    }
    return normalize(left) == normalize(right);
  }
}

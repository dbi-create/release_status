/// Maps user-typed platform names to a canonical service id for matching.
///
/// Aliases normalize names. They do not prove availability and they do not
/// invent a TMDb listing that does not exist.
class PlatformAliases {
  static const Map<String, Set<String>> _aliases = {
    'amazon': {
      'amazon',
      'amazon prime',
      'amazon prime video',
      'amazon video',
      'prime video',
      'prime',
      'amazon prime video with ads',
    },
    'plex': {'plex', 'plex tv', 'plex channel', 'plex free'},
    'fawesome': {
      'fawesome',
      'future today',
      'future today fawesome',
      'future today (fawesome)',
    },
    'ofive_plus': {'ofive+', 'ofive plus', 'ofive', 'ofiveplus'},
    'relay': {'relay', 'relay.film', 'relay film'},
    'netflix': {
      'netflix',
      'netflix standard with ads',
      'netflix basic with ads',
    },
  };

  static const Set<String> _sharedCatalogHosts = {
    'justwatch.com',
    'themoviedb.org',
  };

  static const Map<String, String> _hostIds = {
    'amazon.com': 'amazon',
    'primevideo.com': 'amazon',
    'plex.tv': 'plex',
    'watch.plex.tv': 'plex',
    'netflix.com': 'netflix',
    'relay.film': 'relay',
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

  /// Same channel: TMDb provider id, name alias, specific listing URL, or
  /// a known storefront host. JustWatch catalog pages are not unique.
  static bool sameChannel({
    required String leftName,
    String? leftUrl,
    String? leftProviderId,
    required String rightName,
    String? rightUrl,
    String? rightProviderId,
  }) {
    final leftId = leftProviderId?.trim();
    final rightId = rightProviderId?.trim();
    if (leftId != null &&
        leftId.isNotEmpty &&
        rightId != null &&
        rightId.isNotEmpty &&
        leftId == rightId) {
      return true;
    }
    if (referToSameService(leftName, rightName)) {
      return true;
    }
    final leftHostId = canonicalIdFromUrl(leftUrl);
    final rightHostId = canonicalIdFromUrl(rightUrl);
    final leftNameId = canonicalId(leftName);
    final rightNameId = canonicalId(rightName);
    if (leftHostId != null &&
        (leftHostId == rightNameId || leftHostId == rightHostId)) {
      return true;
    }
    if (rightHostId != null && rightHostId == leftNameId) {
      return true;
    }
    final leftNorm = specificListingUrl(leftUrl);
    final rightNorm = specificListingUrl(rightUrl);
    return leftNorm != null && leftNorm == rightNorm;
  }

  /// Keep a user-pasted storefront URL instead of TMDb's shared JustWatch link.
  static String? preferSpecificListingUrl(String? current, String? incoming) {
    return specificListingUrl(current) ??
        specificListingUrl(incoming) ??
        _trimmedOrNull(current) ??
        _trimmedOrNull(incoming);
  }

  static String? canonicalIdFromUrl(String? url) {
    final host = _host(url);
    if (host == null || _isSharedCatalogHost(host)) {
      return null;
    }
    return _hostIds[host];
  }

  static String? specificListingUrl(String? url) {
    final parsed = _parseUrl(url);
    if (parsed == null || _isSharedCatalogHost(_bareHost(parsed.host))) {
      return null;
    }
    return '${parsed.scheme}://${parsed.host}${parsed.path}'.replaceAll(
      RegExp(r'/+$'),
      '',
    );
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static Uri? _parseUrl(String? url) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return Uri.tryParse(trimmed);
  }

  static String? _host(String? url) {
    final parsed = _parseUrl(url);
    if (parsed == null) {
      return null;
    }
    return _bareHost(parsed.host);
  }

  static String _bareHost(String host) {
    final lower = host.trim().toLowerCase();
    return lower.startsWith('www.') ? lower.substring(4) : lower;
  }

  static bool _isSharedCatalogHost(String host) {
    return _sharedCatalogHosts.any(
      (catalog) => host == catalog || host.endsWith('.$catalog'),
    );
  }
}

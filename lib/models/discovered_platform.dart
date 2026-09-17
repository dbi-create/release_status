/// A public listing from an availability source that is not (yet) one of
/// the user's licensed platforms.
class DiscoveredPlatform {
  const DiscoveredPlatform({
    required this.providerName,
    required this.sourceName,
    this.listingUrl,
  });

  final String providerName;
  final String sourceName;
  final String? listingUrl;

  Map<String, Object?> toJson() {
    return {
      'providerName': providerName,
      'sourceName': sourceName,
      'listingUrl': listingUrl,
    };
  }

  factory DiscoveredPlatform.fromJson(Map<String, Object?> json) {
    return DiscoveredPlatform(
      providerName: json['providerName'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? 'Availability source',
      listingUrl: json['listingUrl'] as String?,
    );
  }
}

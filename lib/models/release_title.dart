import 'package:flutter/material.dart';

import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/monitoring/title_identity.dart';

class ReleaseTitle {
  const ReleaseTitle({
    required this.id,
    required this.name,
    required this.releaseYear,
    required this.contentType,
    required this.placeholderColor,
    required this.platforms,
    this.imdbId,
    this.tmdbId,
    this.availabilityProviderId,
    this.posterUrl,
    this.discoveredPlatforms = const [],
    this.director,
    this.producer,
    this.writer,
    this.alternateTitle,
    this.pinned = false,
    this.lastLookedUpAt,
  });

  final String id;
  final String name;
  final int releaseYear;
  final String contentType;
  final Color placeholderColor;
  final List<PlatformStatus> platforms;
  final String? imdbId;
  final String? tmdbId;
  final String? availabilityProviderId;
  final String? posterUrl;
  final List<DiscoveredPlatform> discoveredPlatforms;
  final String? director;
  final String? producer;
  final String? writer;
  final String? alternateTitle;
  final bool pinned;
  final DateTime? lastLookedUpAt;

  TitleIdentity get identity => TitleIdentity(
    title: name,
    contentType: contentType,
    releaseYear: releaseYear,
    imdbId: imdbId,
    tmdbId: tmdbId,
    availabilityProviderId: availabilityProviderId,
    director: director,
    producer: producer,
    writer: writer,
    alternateTitle: alternateTitle,
  );

  int get licensedPlatformCount => platforms.length;

  int get livePlatformCount => platforms
      .where((platform) => platform.status == DistributionStatus.live)
      .length;

  int get waitingPlatformCount => platforms
      .where((platform) => platform.status == DistributionStatus.waiting)
      .length;

  int get originalNetworkPlatformCount => platforms
      .where((platform) => platform.status == DistributionStatus.originalNetwork)
      .length;

  int get liveOrOnAirPlatformCount =>
      livePlatformCount + originalNetworkPlatformCount;

  String get platformsLiveSummary {
    final total = licensedPlatformCount;
    final count = liveOrOnAirPlatformCount;
    if (originalNetworkPlatformCount > 0) {
      return '$count of $total platforms live or on air';
    }
    return '$count of $total platforms live';
  }

  int get removedPlatformCount => platforms
      .where((platform) => platform.status == DistributionStatus.removed)
      .length;

  String get initials {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word.toUpperCase();
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  ReleaseTitle copyWith({
    String? name,
    int? releaseYear,
    String? contentType,
    Color? placeholderColor,
    List<PlatformStatus>? platforms,
    String? imdbId,
    String? tmdbId,
    String? availabilityProviderId,
    String? posterUrl,
    List<DiscoveredPlatform>? discoveredPlatforms,
    String? director,
    String? producer,
    String? writer,
    String? alternateTitle,
    bool? pinned,
    DateTime? lastLookedUpAt,
  }) {
    return ReleaseTitle(
      id: id,
      name: name ?? this.name,
      releaseYear: releaseYear ?? this.releaseYear,
      contentType: contentType ?? this.contentType,
      placeholderColor: placeholderColor ?? this.placeholderColor,
      platforms: platforms ?? this.platforms,
      imdbId: _replaced(imdbId, this.imdbId),
      tmdbId: _replaced(tmdbId, this.tmdbId),
      availabilityProviderId: _replaced(
        availabilityProviderId,
        this.availabilityProviderId,
      ),
      posterUrl: _replaced(posterUrl, this.posterUrl),
      discoveredPlatforms: discoveredPlatforms ?? this.discoveredPlatforms,
      director: _replaced(director, this.director),
      producer: _replaced(producer, this.producer),
      writer: _replaced(writer, this.writer),
      alternateTitle: _replaced(alternateTitle, this.alternateTitle),
      pinned: pinned ?? this.pinned,
      lastLookedUpAt: lastLookedUpAt ?? this.lastLookedUpAt,
    );
  }
}

String? _replaced(String? incoming, String? current) {
  if (incoming == null) {
    return current;
  }
  final trimmed = incoming.trim();
  return trimmed.isEmpty ? null : trimmed;
}

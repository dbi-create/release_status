import 'package:flutter/material.dart';

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

  TitleIdentity get identity => TitleIdentity(
    title: name,
    contentType: contentType,
    releaseYear: releaseYear,
    imdbId: imdbId,
    tmdbId: tmdbId,
    availabilityProviderId: availabilityProviderId,
  );

  int get licensedPlatformCount => platforms.length;

  int get livePlatformCount => platforms
      .where((platform) => platform.status == DistributionStatus.live)
      .length;

  int get waitingPlatformCount => platforms
      .where((platform) => platform.status == DistributionStatus.waiting)
      .length;

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
  }) {
    return ReleaseTitle(
      id: id,
      name: name ?? this.name,
      releaseYear: releaseYear ?? this.releaseYear,
      contentType: contentType ?? this.contentType,
      placeholderColor: placeholderColor ?? this.placeholderColor,
      platforms: platforms ?? this.platforms,
      imdbId: imdbId ?? this.imdbId,
      tmdbId: tmdbId ?? this.tmdbId,
      availabilityProviderId:
          availabilityProviderId ?? this.availabilityProviderId,
    );
  }
}

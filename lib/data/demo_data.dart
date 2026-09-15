import 'package:flutter/material.dart';

import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';

/// Local demonstration catalog only. Not live monitoring data.
const int demoStatusChangeCount = 2;

/// Shared last-checked label. Intentionally marked as local demo data.
const String demoLastCheckedLabel = '14 Sep 2026';

const List<ReleaseTitle> demoTitles = [
  ReleaseTitle(
    id: 'marked',
    name: 'MARKED',
    releaseYear: 2024,
    contentType: 'Movie',
    placeholderColor: Color(0xFF3A4A63),
    platforms: [
      PlatformStatus(
        platformName: 'Platform One',
        status: DistributionStatus.live,
        firstDetectedLabel: 'Jan 18, 2026',
        lastCheckedLabel: demoLastCheckedLabel,
      ),
      PlatformStatus(
        platformName: 'Platform Two',
        status: DistributionStatus.live,
        firstDetectedLabel: 'Mar 4, 2026',
        lastCheckedLabel: demoLastCheckedLabel,
      ),
      PlatformStatus(
        platformName: 'Platform Three',
        status: DistributionStatus.waiting,
        lastCheckedLabel: demoLastCheckedLabel,
      ),
      PlatformStatus(
        platformName: 'Platform Four',
        status: DistributionStatus.live,
        firstDetectedLabel: 'Jun 21, 2026',
        lastCheckedLabel: demoLastCheckedLabel,
      ),
      PlatformStatus(
        platformName: 'Platform Five',
        status: DistributionStatus.waiting,
        lastCheckedLabel: demoLastCheckedLabel,
      ),
    ],
  ),
  ReleaseTitle(
    id: 'ashen-field',
    name: 'ASHEN FIELD',
    releaseYear: 2023,
    contentType: 'Movie',
    placeholderColor: Color(0xFF4A5340),
    platforms: [
      PlatformStatus(
        platformName: 'Platform One',
        status: DistributionStatus.live,
        firstDetectedLabel: 'Feb 9, 2026',
        lastCheckedLabel: demoLastCheckedLabel,
      ),
      PlatformStatus(
        platformName: 'Platform Two',
        status: DistributionStatus.waiting,
        lastCheckedLabel: demoLastCheckedLabel,
      ),
      PlatformStatus(
        platformName: 'Platform Three',
        status: DistributionStatus.removed,
        firstDetectedLabel: 'Nov 2, 2025',
        lastCheckedLabel: demoLastCheckedLabel,
      ),
    ],
  ),
  ReleaseTitle(
    id: 'northwater',
    name: 'NORTHWATER',
    releaseYear: 2025,
    contentType: 'TV Series',
    placeholderColor: Color(0xFF2F4A4E),
    platforms: [
      PlatformStatus(
        platformName: 'Platform One',
        status: DistributionStatus.live,
        firstDetectedLabel: 'Apr 12, 2026',
        lastCheckedLabel: demoLastCheckedLabel,
      ),
      PlatformStatus(
        platformName: 'Platform Two',
        status: DistributionStatus.live,
        firstDetectedLabel: 'May 30, 2026',
        lastCheckedLabel: demoLastCheckedLabel,
      ),
    ],
  ),
];

int get demoTotalTitleCount => demoTitles.length;

int get demoLivePlatformCount =>
    demoTitles.fold<int>(0, (sum, title) => sum + title.livePlatformCount);

int get demoWaitingPlatformCount =>
    demoTitles.fold<int>(0, (sum, title) => sum + title.waitingPlatformCount);

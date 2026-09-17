import 'dart:io';

import 'package:flutter/material.dart';

import 'package:release_status/data/demo_data.dart';
import 'package:release_status/models/app_settings.dart';
import 'package:release_status/models/discovered_platform.dart';
import 'package:release_status/models/license_relationship.dart';
import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/apply_monitoring_result.dart';
import 'package:release_status/notifications/live_alert.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/discovery_monitor.dart';
import 'package:release_status/monitoring/discovery_result.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/platform_aliases.dart';
import 'package:release_status/monitoring/removal_policy.dart';
import 'package:release_status/monitoring/request_policy.dart';
import 'package:release_status/state/catalog_attention.dart';
import 'package:release_status/cloud/cloud_catalog_sync.dart';
import 'package:release_status/storage/catalog_backup.dart';
import 'package:release_status/storage/catalog_codec.dart';
import 'package:release_status/storage/catalog_store.dart';
import 'package:release_status/storage/status_report.dart';

const List<Color> _placeholderColors = [
  Color(0xFF3A4A63),
  Color(0xFF4A5340),
  Color(0xFF2F4A4E),
  Color(0xFF5A3E48),
  Color(0xFF3E4A5A),
];

class CatalogCheckProgress {
  const CatalogCheckProgress({
    required this.currentTitleIndex,
    required this.totalTitles,
    required this.currentTitleName,
    this.failedTitleNames = const [],
    this.newlyDiscoveredNames = const [],
    this.nowLiveNames = const [],
    this.completed = false,
  });

  final int currentTitleIndex;
  final int totalTitles;
  final String currentTitleName;
  final List<String> failedTitleNames;
  final List<String> newlyDiscoveredNames;
  final List<String> nowLiveNames;
  final bool completed;

  String get label {
    if (completed) {
      final parts = <String>['Checked $totalTitles titles'];
      if (failedTitleNames.isNotEmpty) {
        parts.add('${failedTitleNames.length} could not be completed');
      }
      if (newlyDiscoveredNames.isNotEmpty) {
        parts.add('${newlyDiscoveredNames.length} new platforms discovered');
      }
      if (nowLiveNames.isNotEmpty) {
        parts.add('${nowLiveNames.length} now live');
      }
      return parts.join('. ');
    }
    return 'Checking $currentTitleName  ·  $currentTitleIndex of $totalTitles';
  }
}

class CheckFeedback {
  const CheckFeedback({
    required this.titleId,
    this.newlyDiscoveredNames = const [],
    this.nowLiveNames = const [],
    this.lookedUpPublicListings = false,
  });

  final String titleId;
  final List<String> newlyDiscoveredNames;
  final List<String> nowLiveNames;
  final bool lookedUpPublicListings;
}

/// User catalog. Screens talk to this notifier, not to the store.
class TitleCatalog extends ChangeNotifier {
  TitleCatalog({
    List<ReleaseTitle>? initialTitles,
    CatalogSnapshot? initialSnapshot,
    this.requestPolicy = MonitoringRequestPolicy.immediate,
    this.removalPolicy = RemovalConfirmationPolicy.standard,
    this.store,
    this.cloudSync,
  }) {
    if (initialTitles != null) {
      _titles = List<ReleaseTitle>.from(initialTitles);
      _createdCount = initialSnapshot?.createdCount ?? 0;
      _settings = initialSnapshot?.settings ?? const AppSettings();
      return;
    }

    final snapshot = initialSnapshot;
    if (snapshot != null && snapshot.existedOnDisk) {
      _titles = List<ReleaseTitle>.from(snapshot.titles);
      _createdCount = snapshot.createdCount;
      _settings = snapshot.settings;
      return;
    }

    _titles = List<ReleaseTitle>.from(demoTitles);
    _createdCount = snapshot?.createdCount ?? 0;
    _settings = snapshot?.settings ?? const AppSettings();
    if (store != null && (snapshot == null || !snapshot.existedOnDisk)) {
      _writeQueue = _writeQueue.then((_) => _persist());
    }
  }

  final CatalogStore? store;
  CloudCatalogSync? cloudSync;
  final MonitoringRequestPolicy requestPolicy;
  final RemovalConfirmationPolicy removalPolicy;
  Future<void> Function(List<LiveAlert> alerts)? onTitlesWentLive;

  late List<ReleaseTitle> _titles;
  late int _createdCount;
  late AppSettings _settings;

  bool _checking = false;
  CatalogCheckProgress? _checkProgress;
  CheckFeedback? _lastCheckFeedback;
  Future<void> _writeQueue = Future<void>.value();

  List<ReleaseTitle> get titles => List<ReleaseTitle>.unmodifiable(_titles);

  List<ReleaseTitle> get pinnedTitles => [
    for (final title in _titles)
      if (title.pinned) title,
  ];

  AppSettings get settings => _settings;

  bool get isChecking => _checking;

  CatalogCheckProgress? get checkProgress => _checkProgress;

  CheckFeedback? get lastCheckFeedback => _lastCheckFeedback;

  String? lastCloudError;

  /// Completes when outstanding local writes finish.
  Future<void> get persistCompleted => _writeQueue;

  int get totalTitleCount => _titles.length;

  int get licensedPlatformCount =>
      _titles.fold<int>(0, (sum, title) => sum + title.licensedPlatformCount);

  int get livePlatformCount =>
      _titles.fold<int>(0, (sum, title) => sum + title.livePlatformCount);

  int get liveOrOnAirPlatformCount => _titles.fold<int>(
    0,
    (sum, title) => sum + title.liveOrOnAirPlatformCount,
  );

  int get waitingPlatformCount =>
      _titles.fold<int>(0, (sum, title) => sum + title.waitingPlatformCount);

  int get removedPlatformCount =>
      _titles.fold<int>(0, (sum, title) => sum + title.removedPlatformCount);

  CatalogAttention get attention => catalogAttention(
    _titles,
    notificationsClearedAt: _settings.notificationsClearedAt,
  );

  CatalogSnapshot get snapshot => CatalogSnapshot(
    titles: titles,
    createdCount: _createdCount,
    settings: _settings,
    existedOnDisk: true,
  );

  ReleaseTitle? titleById(String id) {
    for (final title in _titles) {
      if (title.id == id) {
        return title;
      }
    }
    return null;
  }

  ReleaseTitle addTitle({
    required String name,
    required String contentType,
    required int releaseYear,
    required List<String> platformNames,
    List<PlatformStatus>? platforms,
    String? imdbId,
    String? tmdbId,
    String? availabilityProviderId,
    String? director,
    String? producer,
    String? writer,
    String? posterUrl,
    DateTime? lastLookedUpAt,
  }) {
    _createdCount += 1;
    final resolvedTmdbId = _optionalId(tmdbId);
    final title = ReleaseTitle(
      id: 'title-$_createdCount',
      name: name,
      releaseYear: releaseYear,
      contentType: contentType,
      placeholderColor:
          _placeholderColors[_titles.length % _placeholderColors.length],
      platforms: List<PlatformStatus>.from(
        platforms ??
            [
              for (final platformName in platformNames)
                PlatformStatus.waiting(platformName),
            ],
      ),
      imdbId: _optionalId(imdbId),
      tmdbId: resolvedTmdbId,
      availabilityProviderId: _optionalId(availabilityProviderId),
      director: _optionalId(director),
      producer: _optionalId(producer),
      writer: _optionalId(writer),
      posterUrl: _optionalId(posterUrl),
      lastLookedUpAt:
          lastLookedUpAt ??
          (resolvedTmdbId == null ? null : DateTime.now()),
    );
    _titles.add(title);
    _commit();
    return title;
  }

  void updateTitle(ReleaseTitle title) {
    final index = _titles.indexWhere((item) => item.id == title.id);
    if (index < 0) {
      return;
    }
    _titles[index] = title;
    _commit();
  }

  void removeTitle(String id) {
    _titles.removeWhere((title) => title.id == id);
    _commit();
  }

  void setTitlePinned(String id, bool pinned) {
    final title = titleById(id);
    if (title == null || title.pinned == pinned) {
      return;
    }
    updateTitle(title.copyWith(pinned: pinned));
  }

  void replaceAllTitles(List<ReleaseTitle> titles, {int? createdCount}) {
    _titles = List<ReleaseTitle>.from(titles);
    if (createdCount != null) {
      _createdCount = createdCount;
    }
    _commit();
  }

  void clearAllTitles() {
    _titles = [];
    _commit();
  }

  void restoreStarterTitles() {
    _titles = List<ReleaseTitle>.from(demoTitles);
    _createdCount = 0;
    _commit();
  }

  void replaceSnapshot(CatalogSnapshot snapshot) {
    _titles = List<ReleaseTitle>.from(snapshot.titles);
    _createdCount = snapshot.createdCount;
    _settings = snapshot.settings;
    _lastCheckFeedback = null;
    _checkProgress = null;
    _commit();
  }

  bool get canBackupCatalog => store is JsonFileCatalogStore;

  bool get canExportStatusReport => canBackupCatalog && _titles.isNotEmpty;

  Future<CatalogExportResult> exportBackup({DateTime? now}) async {
    final catalogStore = store;
    if (catalogStore is! JsonFileCatalogStore) {
      throw StateError('Catalog export needs the local file store.');
    }
    return exportCatalogBackup(
      snapshot: snapshot,
      catalogDirectory: catalogStore.directory,
      downloadsDirectory:
          catalogStore.downloadsDirectory ?? defaultDownloadsDirectory(),
      now: now,
    );
  }

  Future<StatusReportExportResult> exportStatusReport({DateTime? now}) async {
    final catalogStore = store;
    if (catalogStore is! JsonFileCatalogStore) {
      throw StateError('Status report export needs the local file store.');
    }
    return exportStatusReportFiles(
      snapshot: snapshot,
      catalogDirectory: catalogStore.directory,
      downloadsDirectory:
          catalogStore.downloadsDirectory ?? defaultDownloadsDirectory(),
      now: now,
    );
  }

  Future<File?> latestBackupFile() async {
    final catalogStore = store;
    if (catalogStore is! JsonFileCatalogStore) {
      return null;
    }
    return latestCatalogBackup(catalogStore.directory);
  }

  Future<void> restoreLatestBackup() async {
    final file = await latestBackupFile();
    if (file == null) {
      throw const FormatException('No catalog backup was found.');
    }
    replaceSnapshot(await importCatalogBackup(file));
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    _commit();
  }

  void clearNotifications() {
    updateSettings(
      _settings.copyWith(notificationsClearedAt: DateTime.now()),
    );
  }

  void markPlatformSeenLive({
    required String titleId,
    required String platformName,
    String? listingUrl,
    DateTime? confirmedAt,
  }) {
    final title = titleById(titleId);
    if (title == null) {
      return;
    }
    final at = confirmedAt ?? DateTime.now();
    updateTitle(
      title.copyWith(
        platforms: [
          for (final platform in title.platforms)
            if (platform.platformName == platformName)
              applyUserConfirmedLive(
                platform,
                confirmedAt: at,
                listingUrl: listingUrl,
              )
            else
              platform,
        ],
      ),
    );
  }

  void removeUserConfirmedLive({
    required String titleId,
    required String platformName,
    DateTime? clearedAt,
  }) {
    final title = titleById(titleId);
    if (title == null) {
      return;
    }
    final at = clearedAt ?? DateTime.now();
    updateTitle(
      title.copyWith(
        platforms: [
          for (final platform in title.platforms)
            if (platform.platformName == platformName)
              applyClearUserConfirmedLive(platform, clearedAt: at)
            else
              platform,
        ],
      ),
    );
  }

  void applyMonitoringResults(String titleId, List<MonitoringResult> results) {
    final title = titleById(titleId);
    if (title == null) {
      return;
    }
    final byPlatform = <String, MonitoringResult>{
      for (final result in results) result.platformName: result,
    };
    MonitoringResult? discoverySource;
    for (final result in results) {
      if (result.hasVerifiedIdentity) {
        discoverySource = result;
        break;
      }
    }
    updateTitle(
      title.copyWith(
        tmdbId: discoverySource?.matchedTmdbId ?? title.tmdbId,
        posterUrl: discoverySource?.posterUrl ?? title.posterUrl,
        platforms: [
          for (final platform in title.platforms)
            if (byPlatform.containsKey(platform.platformName))
              applyMonitoringResult(
                platform,
                byPlatform[platform.platformName]!,
                removalPolicy: removalPolicy,
              )
            else
              platform,
        ],
      ),
    );
  }

  /// Merges verified discovery into existing platforms and auto-adds the rest.
  List<String> applyDiscovery(String titleId, DiscoveryResult discovery) {
    final title = titleById(titleId);
    if (title == null) {
      return const [];
    }
    if (discovery.failed || !discovery.isVerified) {
      if (discovery.failed) {
        return const [];
      }
      final checkedAt = discovery.checkedAt ?? DateTime.now();
      updateTitle(
        title.copyWith(
          lastLookedUpAt: checkedAt,
          platforms: [
            for (final platform in title.platforms)
              applyMonitoringResult(
                platform,
                MonitoringResult.notVerified(
                  platformName: platform.platformName,
                  checkedAt: checkedAt,
                  sourceName: discovery.sourceName,
                  matchConfidence: discovery.matchConfidence,
                  message: discovery.matchConfidence == MatchConfidence.possibleMatch
                      ? 'This title could not be confidently matched'
                      : 'Not detected yet',
                  detail: discovery.detail,
                ),
              ),
          ],
        ),
      );
      return const [];
    }

    final checkedAt = discovery.checkedAt ?? DateTime.now();
    final updatedPlatforms = <PlatformStatus>[
      for (final platform in title.platforms)
        _updatedExistingFromDiscovery(platform, discovery, checkedAt),
    ];
    final newlyAdded = <String>[];
    for (final listing in discovery.platforms) {
      if (_hasPlatform(updatedPlatforms, listing)) {
        continue;
      }
      newlyAdded.add(listing.displayName);
      if (!listing.countsAsLiveEvidence) {
        final waiting = PlatformStatus.waiting(
          listing.displayName,
          origin: PlatformOrigin.automatic,
          licenseRelationship: LicenseRelationship.unknown,
        );
        updatedPlatforms.add(
          withAutomatedStatusHistory(
            current: waiting,
            next: waiting.copyWith(
              status: DistributionStatus.originalNetwork,
              lastCheckedAt: checkedAt,
              lastCheckedLabel: formatMonitoringTimestamp(checkedAt),
              statusMessage: 'Original network',
              statusDetail: listing.detail,
              lastMonitoringSource: listing.sourceName,
              lastMatchConfidence: MatchConfidence.verifiedMatch,
            ),
            timestamp: checkedAt,
            sourceName: listing.sourceName,
            reason: listing.detail ?? 'Listed as the original network.',
          ),
        );
        continue;
      }
      updatedPlatforms.add(
        applyMonitoringResult(
          PlatformStatus.waiting(
            listing.displayName,
            origin: PlatformOrigin.automatic,
            licenseRelationship: LicenseRelationship.unknown,
          ),
          _liveResultFromListing(listing, checkedAt),
        ).copyWith(sourceProviderId: listing.sourceProviderId),
      );
    }

    updateTitle(
      title.copyWith(
        tmdbId: discovery.matchedTmdbId ?? title.tmdbId,
        imdbId: discovery.matchedImdbId ?? title.imdbId,
        posterUrl: discovery.posterUrl ?? title.posterUrl,
        director: title.director ?? discovery.director,
        producer: title.producer ?? discovery.producer,
        writer: title.writer ?? discovery.writer,
        discoveredPlatforms: const [],
        platforms: updatedPlatforms,
        lastLookedUpAt: checkedAt,
      ),
    );
    return newlyAdded;
  }

  void addDiscoveredPlatforms(
    String titleId,
    List<DiscoveredPlatform> listings, {
    DateTime? checkedAt,
  }) {
    final title = titleById(titleId);
    if (title == null) {
      return;
    }
    applyDiscovery(
      titleId,
      DiscoveryResult(
        matchConfidence: MatchConfidence.verifiedMatch,
        sourceName: listings.isEmpty
            ? 'Availability source'
            : listings.first.sourceName,
        checkedAt: checkedAt,
        matchedTmdbId: title.tmdbId,
        platforms: [
          for (final listing in listings)
            DiscoveredAvailability(
              displayName: listing.providerName,
              sourceName: listing.sourceName,
              listingUrl: listing.listingUrl,
            ),
        ],
      ),
    );
  }

  /// Sequential check of one title. No-op if a check is already running.
  Future<void> checkTitle(String titleId, AvailabilityMonitor monitor) async {
    if (_checking) {
      return;
    }
    final title = titleById(titleId);
    if (title == null) {
      return;
    }
    _checking = true;
    final previouslyLive = _livePlatformKeys();
    _checkProgress = CatalogCheckProgress(
      currentTitleIndex: 1,
      totalTitles: 1,
      currentTitleName: title.name,
    );
    notifyListeners();
    try {
      await _checkSingleTitle(title, monitor);
      await _emitWentLive(_newLiveAlerts(previouslyLive));
    } catch (_) {
      // Individual platform rows already record check failures.
    } finally {
      _checking = false;
      _checkProgress = null;
      notifyListeners();
    }
  }

  /// Sequential check of every title. One failure does not abort the rest.
  Future<void> checkAllTitles(AvailabilityMonitor monitor) async {
    if (_checking) {
      return;
    }
    final queued = List<ReleaseTitle>.from(_titles);
    if (queued.isEmpty) {
      return;
    }
    _checking = true;
    final failed = <String>[];
    final discovered = <String>[];
    final previouslyLive = _livePlatformKeys();
    notifyListeners();
    try {
      for (var i = 0; i < queued.length; i++) {
        final title = titleById(queued[i].id) ?? queued[i];
        _checkProgress = CatalogCheckProgress(
          currentTitleIndex: i + 1,
          totalTitles: queued.length,
          currentTitleName: title.name,
          failedTitleNames: List<String>.from(failed),
        );
        notifyListeners();
        try {
          await _checkSingleTitle(title, monitor);
          final updated = titleById(title.id) ?? title;
          if (updated.platforms.any((platform) => platform.lastCheckFailed)) {
            failed.add(title.name);
          }
          final feedback = _lastCheckFeedback;
          if (feedback != null && feedback.titleId == title.id) {
            discovered.addAll(feedback.newlyDiscoveredNames);
          }
        } catch (_) {
          failed.add(title.name);
        }
      }
      final nowLiveAlerts = _newLiveAlerts(previouslyLive);
      final nowLive = [
        for (final alert in nowLiveAlerts) alert.platformName,
      ];
      _settings = _settings.copyWith(lastCompletedCheckAt: DateTime.now());
      _checkProgress = CatalogCheckProgress(
        currentTitleIndex: queued.length,
        totalTitles: queued.length,
        currentTitleName: queued.last.name,
        failedTitleNames: failed,
        newlyDiscoveredNames: discovered,
        nowLiveNames: nowLive,
        completed: true,
      );
      await _persist();
      await _emitWentLive(nowLiveAlerts);
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  void dismissCheckProgress() {
    if (_checking) {
      return;
    }
    _checkProgress = null;
    notifyListeners();
  }

  Future<void> _checkSingleTitle(
    ReleaseTitle title,
    AvailabilityMonitor monitor,
  ) async {
    DiscoveryResult? discovery;
    if (monitor is DiscoveryMonitor) {
      final discoveryMonitor = monitor as DiscoveryMonitor;
      try {
        discovery = await discoveryMonitor.discover(title: title.identity);
      } catch (_) {
        discovery = DiscoveryResult.failed(
          sourceName: monitor.displayName,
          checkedAt: DateTime.now(),
          detail: 'Could not complete this check',
        );
      }
    }

    if (discovery != null && discovery.isVerified) {
      final before = {
        for (final platform in title.platforms)
          if (platform.status == DistributionStatus.live) platform.platformName,
      };
      // TMDb watch providers can go LIVE. TV networks are added as AIRS ON.
      final added = applyDiscovery(title.id, discovery);
      final after = titleById(title.id);
      final nowLive = [
        if (after != null)
          for (final platform in after.platforms)
            if (platform.status == DistributionStatus.live &&
                !before.contains(platform.platformName))
              platform.platformName,
      ];
      _lastCheckFeedback = CheckFeedback(
        titleId: title.id,
        newlyDiscoveredNames: added,
        nowLiveNames: nowLive,
        lookedUpPublicListings: true,
      );
      return;
    }

    if (discovery != null && !discovery.failed) {
      applyDiscovery(title.id, discovery);
      _lastCheckFeedback = CheckFeedback(
        titleId: title.id,
        lookedUpPublicListings: true,
      );
      return;
    }

    final current = titleById(title.id) ?? title;
    final results = <MonitoringResult>[];
    for (var i = 0; i < current.platforms.length; i++) {
      if (i > 0 && requestPolicy.delayBetweenRequests > Duration.zero) {
        await Future<void>.delayed(requestPolicy.delayBetweenRequests);
      }
      final platform = current.platforms[i];
      try {
        results.add(
          await monitor.check(
            title: current.identity,
            licensedPlatform: platform.platformName,
          ),
        );
      } catch (_) {
        results.add(
          MonitoringResult.failed(
            platformName: platform.platformName,
            checkedAt: DateTime.now(),
            detail: 'Could not complete this check',
          ),
        );
      }
    }
    if (results.isNotEmpty) {
      applyMonitoringResults(current.id, results);
    }
    _lastCheckFeedback = CheckFeedback(titleId: current.id);
  }

  PlatformStatus _updatedExistingFromDiscovery(
    PlatformStatus platform,
    DiscoveryResult discovery,
    DateTime checkedAt,
  ) {
    final listing = _listingForPlatform(discovery.platforms, platform);
    var updated = applyMonitoringResult(
      platform,
      _resultForExistingPlatform(platform, discovery, checkedAt),
      removalPolicy: removalPolicy,
    ).copyWith(
      sourceProviderId: listing?.sourceProviderId ?? platform.sourceProviderId,
    );
    if (listing != null &&
        !listing.countsAsLiveEvidence &&
        !updated.isUserConfirmedAvailability &&
        updated.status != DistributionStatus.live &&
        updated.status != DistributionStatus.removed) {
      updated = withAutomatedStatusHistory(
        current: updated,
        next: updated.copyWith(
          status: DistributionStatus.originalNetwork,
          statusMessage: 'Original network',
        ),
        timestamp: checkedAt,
        sourceName: listing.sourceName,
        reason: listing.detail ?? 'Listed as the original network.',
      );
    }
    return updated;
  }

  MonitoringResult _resultForExistingPlatform(
    PlatformStatus platform,
    DiscoveryResult discovery,
    DateTime checkedAt,
  ) {
    final listing = _listingForPlatform(discovery.platforms, platform);
    final liveListing = listing != null && listing.countsAsLiveEvidence
        ? listing
        : null;
    if (liveListing != null) {
      return _liveResultFromListing(liveListing, checkedAt);
    }
    if (listing != null) {
      if (platform.status == DistributionStatus.live &&
          !platform.isUserConfirmedAvailability) {
        return MonitoringResult.verifiedAbsence(
          platformName: platform.platformName,
          checkedAt: checkedAt,
          evidenceSource: discovery.sourceName,
          sourceName: discovery.sourceName,
          detail:
              'Verified the title, but public availability was not listed for this platform.',
        );
      }
      return MonitoringResult.notVerified(
        platformName: platform.platformName,
        checkedAt: checkedAt,
        sourceName: listing.sourceName,
        matchConfidence: MatchConfidence.verifiedMatch,
        message: listing.countsAsLiveEvidence
            ? 'Not detected yet'
            : 'Original network',
        detail: listing.detail,
      );
    }
    return MonitoringResult.verifiedAbsence(
      platformName: platform.platformName,
      checkedAt: checkedAt,
      evidenceSource: discovery.sourceName,
      sourceName: discovery.sourceName,
      detail:
          'Verified the title, but public availability was not listed for this platform.',
    );
  }

  MonitoringResult _liveResultFromListing(
    DiscoveredAvailability listing,
    DateTime checkedAt,
  ) {
    return MonitoringResult.verifiedLive(
      platformName: listing.displayName,
      checkedAt: checkedAt,
      evidenceSource: listing.sourceName,
      evidenceUrl: listing.listingUrl,
      sourceName: listing.sourceName,
      detail: listing.detail ?? 'Listed as ${listing.displayName}.',
    );
  }

  bool _hasPlatform(
    List<PlatformStatus> platforms,
    DiscoveredAvailability listing,
  ) {
    return platforms.any((platform) => _samePlatform(platform, listing));
  }

  DiscoveredAvailability? _listingForPlatform(
    List<DiscoveredAvailability> listings,
    PlatformStatus platform,
  ) {
    for (final listing in listings) {
      if (_samePlatform(platform, listing)) {
        return listing;
      }
    }
    return null;
  }

  bool _samePlatform(PlatformStatus platform, DiscoveredAvailability listing) {
    if (platform.sourceProviderId != null &&
        listing.sourceProviderId != null &&
        platform.sourceProviderId == listing.sourceProviderId) {
      return true;
    }
    return PlatformAliases.referToSameService(
      platform.platformName,
      listing.displayName,
    );
  }

  void applyCloudSnapshot(CatalogSnapshot snapshot) {
    _titles = List<ReleaseTitle>.from(snapshot.titles);
    _createdCount = snapshot.createdCount;
    _settings = snapshot.settings;
    notifyListeners();
    final catalogStore = store;
    if (catalogStore != null) {
      _writeQueue = _writeQueue.then((_) => catalogStore.save(this.snapshot));
    }
  }

  void _commit() {
    notifyListeners();
    _writeQueue = _writeQueue.then((_) => _persist());
  }

  Future<void> _persist() async {
    final catalogStore = store;
    if (catalogStore == null) {
      return;
    }
    await catalogStore.save(snapshot);
    final sync = cloudSync;
    if (sync == null || !sync.isSignedIn) {
      return;
    }
    try {
      await sync.push(snapshot);
      lastCloudError = null;
    } on Object catch (error) {
      lastCloudError = '$error';
    }
  }

  Future<void> syncToCloud() async {
    final sync = cloudSync;
    if (sync == null || !sync.isSignedIn) {
      return;
    }
    try {
      await sync.push(snapshot);
      lastCloudError = null;
    } on Object catch (error) {
      lastCloudError = '$error';
      rethrow;
    }
  }

  String? _optionalId(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Set<String> _livePlatformKeys() {
    return {
      for (final title in _titles)
        for (final platform in title.platforms)
          if (platform.status == DistributionStatus.live)
            '${title.id}|${platform.platformName}',
    };
  }

  List<LiveAlert> _newLiveAlerts(Set<String> previouslyLive) {
    return [
      for (final title in _titles)
        for (final platform in title.platforms)
          if (platform.status == DistributionStatus.live &&
              !previouslyLive.contains('${title.id}|${platform.platformName}'))
            LiveAlert(
              titleId: title.id,
              titleName: title.name,
              platformName: platform.platformName,
            ),
    ];
  }

  Future<void> _emitWentLive(List<LiveAlert> alerts) async {
    if (alerts.isEmpty || !_settings.liveAlertsEnabled) {
      return;
    }
    await onTitlesWentLive?.call(alerts);
  }
}

class TitleCatalogScope extends InheritedNotifier<TitleCatalog> {
  const TitleCatalogScope({
    super.key,
    required TitleCatalog catalog,
    required super.child,
  }) : super(notifier: catalog);

  static TitleCatalog of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TitleCatalogScope>();
    assert(scope != null, 'TitleCatalogScope not found in context');
    return scope!.notifier!;
  }
}

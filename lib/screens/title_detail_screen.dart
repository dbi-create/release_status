import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/screens/title_form_screen.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/widgets/platform_status_row.dart';
import 'package:release_status/widgets/title_artwork.dart';
import 'package:release_status/widgets/title_card.dart';

class TitleDetailScreen extends StatelessWidget {
  const TitleDetailScreen({super.key, required this.titleId});

  final String titleId;

  @override
  Widget build(BuildContext context) {
    final catalog = TitleCatalogScope.of(context);
    final title = catalog.titleById(titleId);
    if (title == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(title: const Text('Title')),
        body: const Center(
          child: Text('This title is no longer in your catalog.'),
        ),
      );
    }

    final monitor = AvailabilityMonitorScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    final checking = catalog.isChecking;
    final hasRealLookup = title.platforms.any(
      (platform) => platform.hasRealLookup,
    );
    final hasDemoCheck = title.platforms.any(
      (platform) => platform.hasBeenChecked && !platform.hasRealLookup,
    );

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(title.name)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 20 : 32,
          20,
          isCompact ? 20 : 32,
          isCompact ? 96 : 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleArtwork(title: title, size: 88),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.name,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${title.contentType}  ·  Release year ${title.releaseYear}',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatusPhraseText(
                        title.platformsLiveSummary,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TitlePinDeleteIcons(
                  title: title,
                  pinKey: const ValueKey<String>('pin-title-button'),
                  deleteKey: const ValueKey<String>('delete-title-button'),
                  enabled: !checking,
                  onDelete: () => _confirmDelete(context, title),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 65,
                  child: SizedBox(
                    height: 56,
                    child: FilledButton(
                      key: const ValueKey<String>('check-status-button'),
                      onPressed: checking
                          ? null
                          : () => catalog.checkTitle(title.id, monitor),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          checking ? 'Checking…' : 'Recheck Platform Status',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 35,
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.tonal(
                      key: const ValueKey<String>('edit-title-button'),
                      onPressed: checking
                          ? null
                          : () => _openEdit(context, title),
                      child: const Text(
                        'Edit Title',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (checking) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    key: const ValueKey<String>('checking-status-indicator'),
                    catalog.checkProgress?.label ??
                        'Checking public availability…',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (!monitor.isConfigured) ...[
              const SizedBox(height: 16),
              Text(
                'Real availability checks are not configured yet. Recheck Platforms will not contact an external source.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            if (!checking) ...[
              const SizedBox(height: 16),
              _CheckFeedbackBanner(
                title: title,
                feedback: catalog.lastCheckFeedback,
              ),
            ],
            const SizedBox(height: 24),
            _OverallStatusPanel(title: title),
            const SizedBox(height: 32),
            Text(
              'Platform Status',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            for (final platform in title.platforms) ...[
              PlatformStatusRow(
                platform: platform,
                titleId: title.id,
                enabled: !checking,
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 12),
            StatusPhraseText(
              _footerText(
                hasRealLookup: hasRealLookup,
                hasDemoCheck: hasDemoCheck,
              ),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, ReleaseTitle title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TitleFormScreen(existingTitle: title),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ReleaseTitle title) async {
    final confirmed = await confirmDeleteTitle(context, title);
    if (confirmed != true || !context.mounted) {
      return;
    }
    final catalog = TitleCatalogScope.of(context);
    Navigator.of(context).pop();
    catalog.removeTitle(title.id);
  }
}

String _footerText({required bool hasRealLookup, required bool hasDemoCheck}) {
  if (hasRealLookup) {
    return 'Last checked times are stored on this device. They are not a continuous monitor.';
  }
  if (hasDemoCheck) {
    return 'Last Checked values are local demonstration data and are not the result of a network scan.';
  }
  return 'Title is not LIVE or ON AIR on any channels we could find.';
}

class _CheckFeedbackBanner extends StatelessWidget {
  const _CheckFeedbackBanner({required this.title, required this.feedback});

  final ReleaseTitle title;
  final CheckFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    if (feedback == null || feedback!.titleId != title.id) {
      return const SizedBox.shrink();
    }
    if (feedback!.newlyDiscoveredNames.isEmpty &&
        feedback!.nowLiveNames.isEmpty &&
        !feedback!.lookedUpPublicListings) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final discovered = feedback!.newlyDiscoveredNames;
    final heading = discovered.length == 1
        ? 'New platform discovered'
        : discovered.isEmpty
        ? 'Status updated'
        : '${discovered.length} new platforms discovered';
    final body = discovered.isEmpty
        ? feedback!.nowLiveNames.isEmpty
            ? 'No new channels were listed. Existing platforms were updated.'
            : '${title.name} is now available on ${feedback!.nowLiveNames.join(', ')}.'
        : discovered.length == 1
        ? '${title.name} is currently available on ${discovered.single}.'
        : '${title.name} is currently available on ${discovered.join(', ')}.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              key: const ValueKey<String>('new-platform-feedback'),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallStatusPanel extends StatelessWidget {
  const _OverallStatusPanel({required this.title});

  final ReleaseTitle title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Status',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            StatusPhraseText(
              title.platformsLiveSummary,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_overallSummary(title).isNotEmpty) ...[
              const SizedBox(height: 8),
              StatusPhraseText(
                _overallSummary(title),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            StatusSegmentBar(
              height: 10,
              statuses: title.platforms
                  .map((platform) => platform.status)
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendItem(
                  visuals: StatusVisuals.live,
                  count: title.livePlatformCount,
                ),
                if (title.originalNetworkPlatformCount > 0)
                  _LegendItem(
                    visuals: StatusVisuals.originalNetwork,
                    count: title.originalNetworkPlatformCount,
                  ),
                if (title.removedPlatformCount > 0)
                  _LegendItem(
                    visuals: StatusVisuals.removed,
                    count: title.removedPlatformCount,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.visuals, required this.count});

  final StatusVisuals visuals;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(visuals.icon, size: 16, color: visuals.color),
        const SizedBox(width: 6),
        Text(
          '$count ${visuals.label}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: visuals.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _overallSummary(ReleaseTitle title) {
  if (title.removedPlatformCount > 0) {
    return '${title.removedPlatformCount} removed';
  }
  return '';
}

import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';
import 'package:release_status/screens/title_form_screen.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/widgets/platform_status_row.dart';

class TitleDetailScreen extends StatelessWidget {
  const TitleDetailScreen({super.key, required this.titleId});

  final String titleId;

  @override
  Widget build(BuildContext context) {
    final title = TitleCatalogScope.of(context).titleById(titleId);
    if (title == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(title: const Text('Title')),
        body: const Center(
          child: Text('This title is no longer in this session.'),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    final hasCheckedPlatform = title.platforms.any(
      (platform) => platform.hasBeenChecked,
    );

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: Text(title.name)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 20 : 32,
          20,
          isCompact ? 20 : 32,
          40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailMonogram(title: title),
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
                      Text(
                        '${title.livePlatformCount} of ${title.licensedPlatformCount} platforms live',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  key: const ValueKey<String>('edit-title-button'),
                  onPressed: () => _openEdit(context, title),
                  child: const Text('Edit Title'),
                ),
                TextButton(
                  key: const ValueKey<String>('delete-title-button'),
                  onPressed: () => _confirmDelete(context, title),
                  child: const Text('Delete Title'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _OverallStatusPanel(title: title),
            const SizedBox(height: 32),
            Text(
              'Platform Status',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your Platforms  ·  Licensed Platforms for this title',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final platform in title.platforms) ...[
              PlatformStatusRow(platform: platform),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 12),
            Text(
              hasCheckedPlatform
                  ? 'Last Checked values are local demonstration data and are not the result of a network scan.'
                  : 'Monitoring has not started for this title. No availability check has occurred.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Remove ${title.name} from ReleaseStatus?'),
          content: const Text(
            'This removes the title from this local prototype. It is not saved anywhere else.',
          ),
          actions: [
            TextButton(
              key: const ValueKey<String>('cancel-delete-button'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey<String>('confirm-delete-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Title'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final catalog = TitleCatalogScope.of(context);
    Navigator.of(context).pop();
    catalog.removeTitle(title.id);
  }
}

class _DetailMonogram extends StatelessWidget {
  const _DetailMonogram({required this.title});

  final ReleaseTitle title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${title.name} placeholder artwork',
      child: SizedBox(
        width: 88,
        height: 88,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: title.placeholderColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              title.initials,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
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
            Text(
              '${title.livePlatformCount} of ${title.licensedPlatformCount} platforms live',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _overallSummary(title),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
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
                _LegendItem(
                  visuals: StatusVisuals.waiting,
                  count: title.waitingPlatformCount,
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
  final parts = <String>[
    if (title.waitingPlatformCount > 0)
      '${title.waitingPlatformCount} waiting — not yet detected',
    if (title.removedPlatformCount > 0) '${title.removedPlatformCount} removed',
  ];
  if (parts.isEmpty) {
    return 'All licensed platforms are live.';
  }
  return parts.join('  ·  ');
}

import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';
import 'package:release_status/widgets/platform_status_row.dart';

class TitleCard extends StatelessWidget {
  const TitleCard({super.key, required this.title, required this.onViewStatus});

  final ReleaseTitle title;
  final VoidCallback onViewStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey<String>('title-card-${title.id}'),
        onTap: onViewStatus,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleMonogram(title: title),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.name,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${title.contentType}  ·  ${title.releaseYear}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${title.licensedPlatformCount} licensed platforms',
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusSummary(title),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StatusSegmentBar(
                  statuses: title.platforms
                      .map((platform) => platform.status)
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    key: ValueKey<String>('view-status-${title.id}'),
                    onPressed: onViewStatus,
                    child: const Text('View Status'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TitleListTileCard extends StatelessWidget {
  const TitleListTileCard({
    super.key,
    required this.title,
    required this.onViewStatus,
  });

  final ReleaseTitle title;
  final VoidCallback onViewStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onViewStatus,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _TitleMonogram(title: title, size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${title.releaseYear}  ·  ${title.contentType}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${title.livePlatformCount} of ${title.licensedPlatformCount} platforms live',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusSummary(title),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: ValueKey<String>('view-status-${title.id}'),
                  onPressed: onViewStatus,
                  child: const Text('View Status'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleMonogram extends StatelessWidget {
  const _TitleMonogram({required this.title, this.size = 64});

  final ReleaseTitle title;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${title.name} placeholder artwork',
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: title.placeholderColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              title.initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _statusSummary(ReleaseTitle title) {
  final parts = <String>[
    if (title.livePlatformCount > 0) '${title.livePlatformCount} live',
    if (title.waitingPlatformCount > 0) '${title.waitingPlatformCount} waiting',
    if (title.removedPlatformCount > 0) '${title.removedPlatformCount} removed',
  ];
  return parts.join('  ·  ');
}

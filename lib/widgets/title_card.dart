import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/widgets/platform_status_row.dart';
import 'package:release_status/widgets/title_artwork.dart';

const Color kPinnedColor = Color(0xFFFFD60A);

class TitleCard extends StatelessWidget {
  const TitleCard({
    super.key,
    required this.title,
    required this.onViewStatus,
    this.showDelete = true,
  });

  final ReleaseTitle title;
  final VoidCallback onViewStatus;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 8, 0),
                      child: InkWell(
                        key: ValueKey<String>('title-card-${title.id}'),
                        onTap: onViewStatus,
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TitleArtwork(title: title),
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
                                    'LICENSED PLATFORMS: ${title.licensedPlatformCount}',
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TitlePinDeleteIcons(title: title, showDelete: showDelete),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: StatusSegmentBar(
                  statuses: title.platforms
                      .map((platform) => platform.status)
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _ViewTitleButton(
                  titleId: title.id,
                  onViewStatus: onViewStatus,
                ),
              ),
            ],
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
    this.showDelete = true,
  });

  final ReleaseTitle title;
  final VoidCallback onViewStatus;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                      child: InkWell(
                        onTap: onViewStatus,
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            TitleArtwork(title: title, size: 52),
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
                                    'LICENSED PLATFORMS: ${title.licensedPlatformCount}',
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TitlePinDeleteIcons(title: title, showDelete: showDelete),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ViewTitleButton(
                  titleId: title.id,
                  onViewStatus: onViewStatus,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TitlePinDeleteIcons extends StatelessWidget {
  const TitlePinDeleteIcons({
    super.key,
    required this.title,
    this.pinKey,
    this.deleteKey,
    this.enabled = true,
    this.onDelete,
    this.showDelete = true,
  });

  final ReleaseTitle title;
  final Key? pinKey;
  final Key? deleteKey;
  final bool enabled;
  final VoidCallback? onDelete;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final catalog = TitleCatalogScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final buttonStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(36, 36),
      padding: const EdgeInsets.all(6),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: pinKey ?? ValueKey<String>('pin-title-${title.id}'),
          tooltip: title.pinned ? 'Unpin Title' : 'Pin Title',
          style: buttonStyle,
          onPressed: enabled
              ? () => catalog.setTitlePinned(title.id, !title.pinned)
              : null,
          icon: Icon(
            title.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 22,
            color: title.pinned ? kPinnedColor : null,
          ),
        ),
        if (showDelete)
          IconButton(
            key: deleteKey ?? ValueKey<String>('delete-title-${title.id}'),
            tooltip: 'Delete Title',
            style: buttonStyle,
            onPressed: !enabled
                ? null
                : () {
                    if (onDelete != null) {
                      onDelete!();
                      return;
                    }
                    _deleteFromCatalog(context, title);
                  },
            icon: Icon(
              Icons.delete_outline,
              size: 22,
              color: colorScheme.error,
            ),
          ),
      ],
    );
  }
}

class _ViewTitleButton extends StatelessWidget {
  const _ViewTitleButton({
    required this.titleId,
    required this.onViewStatus,
  });

  final String titleId;
  final VoidCallback onViewStatus;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: ValueKey<String>('view-status-$titleId'),
      style: _compactButtonStyle,
      onPressed: onViewStatus,
      child: const Text('View Title'),
    );
  }
}

final ButtonStyle _compactButtonStyle = FilledButton.styleFrom(
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: const Size.fromHeight(32),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
);

Future<void> _deleteFromCatalog(
  BuildContext context,
  ReleaseTitle title,
) async {
  final confirmed = await confirmDeleteTitle(context, title);
  if (confirmed != true || !context.mounted) {
    return;
  }
  TitleCatalogScope.of(context).removeTitle(title.id);
}

Future<bool> confirmDeleteTitle(
  BuildContext context,
  ReleaseTitle title,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Remove ${title.name} from ReleaseStatus?'),
        content: const Text('This removes the title from this device.'),
        actions: [
          TextButton(
            key: const ValueKey<String>('cancel-delete-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey<String>('confirm-delete-button'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Title'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

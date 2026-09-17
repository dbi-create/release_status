import 'package:flutter/material.dart';

import 'package:release_status/models/platform_origin.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/platform_status_event.dart';
import 'package:release_status/state/title_catalog.dart';

class PlatformStatusRow extends StatefulWidget {
  const PlatformStatusRow({
    super.key,
    required this.platform,
    this.titleId,
    this.enabled = true,
  });

  final PlatformStatus platform;
  final String? titleId;
  final bool enabled;

  @override
  State<PlatformStatusRow> createState() => _PlatformStatusRowState();
}

class _PlatformStatusRowState extends State<PlatformStatusRow> {
  bool _historyOpen = false;

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final Widget? action = widget.titleId == null
        ? null
        : platform.canMarkSeenLive
        ? TextButton(
            key: ValueKey<String>(
              'mark-seen-live-${platform.platformName}',
            ),
            style: _rightAlignedTextButtonStyle,
            onPressed: widget.enabled ? () => _confirmSeenLive(context) : null,
            child: const Text('Mark as seen live'),
          )
        : null;

    return Semantics(
      label:
          '${platform.platformName}, ${platform.statusLabel}. '
          '${platform.origin.label}. ${_metaLine(platform)}.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              TextSpan(text: platform.platformName),
                              TextSpan(
                                text: ' - ${platform.origin.label}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _metaLine(platform),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(status: platform.status),
                      if (platform.history.isNotEmpty ||
                          platform.status ==
                              DistributionStatus.originalNetwork)
                        TextButton(
                          key: ValueKey<String>(
                            'platform-history-${platform.platformName}',
                          ),
                          style: _rightAlignedTextButtonStyle,
                          onPressed: () {
                            setState(() {
                              _historyOpen = !_historyOpen;
                            });
                          },
                          child: Text(
                            _historyOpen ? 'Hide history' : 'Status history',
                          ),
                        ),
                      if (action != null) action,
                    ],
                  ),
                ],
              ),
              if (_historyOpen)
                if (platform.history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      platform.statusDetail ??
                          'Listed as the original network.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  )
                else
                  for (final event in platform.history.reversed)
                    _HistoryLine(event: event),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSeenLive(BuildContext context) async {
    final titleId = widget.titleId;
    if (titleId == null) {
      return;
    }
    final result = await showDialog<_SeenLiveDialogResult>(
      context: context,
      builder: (dialogContext) {
        return _SeenLiveDialog(
          platformName: widget.platform.platformName,
          initialUrl: widget.platform.evidenceUrl ?? '',
        );
      },
    );
    if (result == null || !result.confirmed || !context.mounted) {
      return;
    }
    final trimmed = result.listingUrl.trim();
    if (trimmed.isNotEmpty) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter a valid http or https listing URL, or leave it blank.',
            ),
          ),
        );
        return;
      }
    }
    TitleCatalogScope.of(context).markPlatformSeenLive(
      titleId: titleId,
      platformName: widget.platform.platformName,
      listingUrl: trimmed.isEmpty ? null : trimmed,
    );
  }
}

class _SeenLiveDialogResult {
  const _SeenLiveDialogResult({
    required this.confirmed,
    required this.listingUrl,
  });

  final bool confirmed;
  final String listingUrl;
}

class _SeenLiveDialog extends StatefulWidget {
  const _SeenLiveDialog({
    required this.platformName,
    required this.initialUrl,
  });

  final String platformName;
  final String initialUrl;

  @override
  State<_SeenLiveDialog> createState() => _SeenLiveDialogState();
}

class _SeenLiveDialogState extends State<_SeenLiveDialog> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark ${widget.platformName} as seen live?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This records that you saw the title on this platform. It is not an independent listing from TMDb or another availability source.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey<String>('listing-url-field'),
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Listing URL (optional)',
              hintText: 'https://',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('cancel-seen-live-button'),
          onPressed: () => Navigator.of(context).pop(
            _SeenLiveDialogResult(
              confirmed: false,
              listingUrl: _urlController.text,
            ),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('confirm-seen-live-button'),
          onPressed: () => Navigator.of(context).pop(
            _SeenLiveDialogResult(
              confirmed: true,
              listingUrl: _urlController.text,
            ),
          ),
          child: const Text('Mark as seen live'),
        ),
      ],
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.event});

  final PlatformStatusEvent event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final previous = event.previousStatus?.label ?? 'NONE';
    final next = event.newStatus.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: StatusPhraseText(
        '$previous → $next  ·  ${formatStoredTimestamp(event.timestamp)}\n'
        '${event.sourceName}  ·  ${event.reason}',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
    );
  }
}

String _metaLine(PlatformStatus platform) {
  return 'Checked: ${_checkedValue(platform)}';
}

String _checkedValue(PlatformStatus platform) {
  if (platform.lastCheckedLabel != null &&
      platform.lastCheckedLabel!.trim().isNotEmpty) {
    return platform.lastCheckedLabel!;
  }
  return 'Monitoring has not started';
}

final ButtonStyle _rightAlignedTextButtonStyle = TextButton.styleFrom(
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  minimumSize: Size.zero,
  padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
  alignment: Alignment.centerRight,
);

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DistributionStatus status;

  @override
  Widget build(BuildContext context) {
    final visuals = StatusVisuals.of(status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: visuals.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: visuals.color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visuals.icon, size: 14, color: visuals.color),
            const SizedBox(width: 6),
            Text(
              visuals.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: visuals.color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusVisuals {
  const StatusVisuals({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  static const live = StatusVisuals(
    label: 'LIVE',
    icon: Icons.check_circle_outline,
    color: Color(0xFF4CAF7A),
  );

  static const waiting = StatusVisuals(
    label: 'NOT LIVE',
    icon: Icons.schedule,
    color: Color(0xFFD4A017),
  );

  static const originalNetwork = StatusVisuals(
    label: 'AIRS ON',
    icon: Icons.live_tv,
    color: Color(0xFF4A7FB5),
  );

  static const removed = StatusVisuals(
    label: 'REMOVED',
    icon: Icons.remove_circle_outline,
    color: Color(0xFFE05555),
  );

  static StatusVisuals of(DistributionStatus status) {
    switch (status) {
      case DistributionStatus.live:
        return live;
      case DistributionStatus.waiting:
        return waiting;
      case DistributionStatus.originalNetwork:
        return originalNetwork;
      case DistributionStatus.removed:
        return removed;
    }
  }

  static Color? colorForPhrase(String phrase) {
    switch (phrase.toUpperCase()) {
      case 'NOT LIVE':
        return waiting.color;
      case 'AIRS ON':
      case 'ON AIR':
        return originalNetwork.color;
      case 'LIVE':
        return live.color;
      case 'REMOVED':
        return removed.color;
      default:
        return null;
    }
  }
}

/// Colors standalone LIVE green and NOT LIVE orange inside a sentence.
class StatusPhraseText extends StatelessWidget {
  const StatusPhraseText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  static final _pattern = RegExp(
    'NOT LIVE|AIRS ON|ON AIR|LIVE|REMOVED',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      spanFor(text, style),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  static TextSpan spanFor(String text, TextStyle? style) {
    final matches = _pattern.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final phrase = match.group(0)!;
      children.add(
        TextSpan(
          text: phrase,
          style: TextStyle(
            color: StatusVisuals.colorForPhrase(phrase),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}

class StatusSegmentBar extends StatelessWidget {
  const StatusSegmentBar({super.key, required this.statuses, this.height = 8});

  final List<DistributionStatus> statuses;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Platform status progress, ${statuses.length} licensed platforms',
      child: Row(
        children: [
          for (var i = 0; i < statuses.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: ColoredBox(
                color: StatusVisuals.of(statuses[i]).color,
                child: SizedBox(height: height),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

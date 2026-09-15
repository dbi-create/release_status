import 'package:flutter/material.dart';

import 'package:release_status/models/platform_status.dart';

class PlatformStatusRow extends StatelessWidget {
  const PlatformStatusRow({super.key, required this.platform});

  final PlatformStatus platform;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final visuals = StatusVisuals.of(platform.status);

    return Semantics(
      label:
          '${platform.platformName}, ${platform.statusLabel}. '
          '${platform.hasBeenDetected ? 'First detected ${platform.firstDetectedLabel}' : 'Not yet detected'}. '
          '${platform.hasBeenChecked ? 'Last checked, local demo data, ${platform.lastCheckedLabel}.' : 'Monitoring has not started. No check has occurred.'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visuals.icon, color: visuals.color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            platform.platformName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusBadge(status: platform.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      platform.hasBeenDetected
                          ? 'First Detected  ${platform.firstDetectedLabel}'
                          : 'Not yet detected',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      platform.hasBeenChecked
                          ? 'Last Checked (local demo data)  ${platform.lastCheckedLabel}'
                          : 'Monitoring has not started',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    label: 'WAITING',
    icon: Icons.schedule,
    color: Color(0xFFD4A017),
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
      case DistributionStatus.removed:
        return removed;
    }
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

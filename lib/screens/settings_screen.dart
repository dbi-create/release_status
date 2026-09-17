import 'package:flutter/material.dart';

import 'package:release_status/models/app_settings.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/widgets/status_report_export.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = TitleCatalogScope.of(context);
    final monitor = AvailabilityMonitorScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    final showPageBrand = MediaQuery.sizeOf(context).width >= 960;
    final settings = catalog.settings;

    return ColoredBox(
      color: colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 20 : 32,
          isCompact ? 8 : 28,
          isCompact ? 20 : 32,
          isCompact ? 96 : 40,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Settings',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              if (showPageBrand) ...[
                const SizedBox(height: 6),
                Text(
                  'Your titles. Your platforms. Your status.',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Monitoring',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'While this app is open, checks run on this schedule. This app does not check titles while it is closed.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  key: const ValueKey<String>('monitoring-enabled-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Monitoring enabled'),
                  subtitle: Text(
                    monitor.isConfigured
                        ? 'Public availability checks can run from this device.'
                        : 'Availability checking is not configured on this device.',
                  ),
                  value: settings.monitoringEnabled,
                  onChanged: (value) {
                    catalog.updateSettings(
                      settings.copyWith(monitoringEnabled: value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preferred check interval',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final interval in AppSettings.intervalChoices)
                    ChoiceChip(
                      key: ValueKey<String>(
                        'check-interval-${interval.inHours}',
                      ),
                      label: Text(_intervalLabel(interval)),
                      selected: settings.checkInterval == interval,
                      onSelected: (_) {
                        catalog.updateSettings(
                          settings.copyWith(checkInterval: interval),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _scheduleSummary(settings),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Data',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Titles, platform status, and check history are stored on this device. Export a backup before replacing this catalog. Files are not synced to a cloud account.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A status report is a CSV plus a printable HTML table of every title and platform. Files save on this device. If a Downloads copy is blocked, copy them from the path shown after export. Open the HTML file in a browser to print. This is a snapshot, not a live scan.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    key: const ValueKey<String>('export-catalog-button'),
                    onPressed: catalog.isChecking || !catalog.canBackupCatalog
                        ? null
                        : () => _exportCatalog(context, catalog),
                    child: const Text('Export catalog'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey<String>(
                      'export-status-report-settings-button',
                    ),
                    onPressed:
                        catalog.isChecking || !catalog.canExportStatusReport
                        ? null
                        : () => exportStatusReportFlow(context, catalog),
                    child: const Text('Export status report'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey<String>('restore-backup-button'),
                    onPressed: catalog.isChecking || !catalog.canBackupCatalog
                        ? null
                        : () => _restoreBackup(context, catalog),
                    child: const Text('Restore last backup'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey<String>(
                      'restore-starter-titles-button',
                    ),
                    onPressed: catalog.isChecking
                        ? null
                        : () => _confirmRestore(context, catalog),
                    child: const Text('Restore starter titles'),
                  ),
                  TextButton(
                    key: const ValueKey<String>('clear-titles-button'),
                    onPressed: catalog.isChecking
                        ? null
                        : () => _confirmClear(context, catalog),
                    child: const Text('Remove all titles'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'About',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ReleaseStatus',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your titles. Your platforms. Your status.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'For filmmakers and rightsholders tracking whether licensed titles have actually gone live.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCatalog(
    BuildContext context,
    TitleCatalog catalog,
  ) async {
    try {
      final result = await catalog.exportBackup();
      if (!context.mounted) {
        return;
      }
      final downloads = result.downloadsPath;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Catalog exported'),
            content: Text(
              downloads == null
                  ? 'Saved a backup at ${result.backupPath}'
                  : 'Saved a copy in Downloads:\n$downloads\n\nLocal backup:\n${result.backupPath}',
            ),
            actions: [
              TextButton(
                key: const ValueKey<String>('close-export-catalog-button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Could not export catalog'),
            content: Text('$error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _restoreBackup(
    BuildContext context,
    TitleCatalog catalog,
  ) async {
    final file = await catalog.latestBackupFile();
    if (!context.mounted) {
      return;
    }
    if (file == null) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('No backup yet'),
            content: const Text(
              'Export a catalog first. Backups stay on this device.',
            ),
            actions: [
              TextButton(
                key: const ValueKey<String>('close-no-backup-button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore the last catalog backup?'),
          content: const Text(
            'This replaces titles, platform status, and history on this device with the last export.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey<String>('confirm-restore-backup-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore backup'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await catalog.restoreLatestBackup();
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Could not restore backup'),
            content: Text('$error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _confirmClear(BuildContext context, TitleCatalog catalog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove all titles from this device?'),
          content: const Text(
            'This deletes your local catalog, including status history. It cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey<String>('confirm-clear-titles-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove all titles'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      catalog.clearAllTitles();
    }
  }

  Future<void> _confirmRestore(
    BuildContext context,
    TitleCatalog catalog,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore starter titles?'),
          content: const Text(
            'This replaces the catalog on this device with the starter titles.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey<String>('confirm-restore-titles-button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      catalog.restoreStarterTitles();
    }
  }
}

String _intervalLabel(Duration interval) {
  if (interval.inHours == 1) {
    return 'Every hour';
  }
  return 'Every ${interval.inHours} hours';
}

String _scheduleSummary(AppSettings settings) {
  if (!settings.monitoringEnabled) {
    return 'Monitoring is turned off. Status only updates when you check manually.';
  }
  final last = settings.lastCompletedCheckAt;
  final next = settings.nextCheckDue;
  if (last == null) {
    return 'Preferred interval: ${_intervalLabel(settings.checkInterval).toLowerCase()}. The first automatic check will run while this app is open.';
  }
  final nextText = next == null ? '' : ' Next check due ${next.toLocal()}.';
  return 'Last completed check ${last.toLocal()}.$nextText Checks run while this app is open. They do not run while it is closed.';
}

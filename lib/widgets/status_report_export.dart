import 'package:flutter/material.dart';

import 'package:release_status/state/title_catalog.dart';

Future<void> exportStatusReportFlow(
  BuildContext context,
  TitleCatalog catalog,
) async {
  try {
    final result = await catalog.exportStatusReport();
    if (!context.mounted) {
      return;
    }
    final csv = result.downloadsCsvPath;
    final html = result.downloadsHtmlPath;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Status report exported'),
          content: Text(
            csv == null || html == null
                ? 'Saved on this device:\n${result.csvPath}\n${result.htmlPath}\n\nOpen the HTML file in a browser to print. Copy the files from that folder if you want to attach them.'
                : 'Saved in Downloads:\n$csv\n$html\n\nOpen the HTML file in a browser to print.',
          ),
          actions: [
            TextButton(
              key: const ValueKey<String>('close-status-report-button'),
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
          title: const Text('Could not export status report'),
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

import 'package:flutter/material.dart';

import 'package:release_status/cloud/cloud_session.dart';
import 'package:release_status/cloud/cloud_session_scope.dart';
import 'package:release_status/state/title_catalog.dart';

class CloudAccountCard extends StatelessWidget {
  const CloudAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final session = CloudSessionScope.maybeOf(context);
    if (session == null || !session.isConfigured) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (!session.isSignedIn) {
          return const SizedBox.shrink();
        }
        return _CloudAccountBody(session: session);
      },
    );
  }
}

class _CloudAccountBody extends StatelessWidget {
  const _CloudAccountBody({required this.session});

  final CloudSession session;

  @override
  Widget build(BuildContext context) {
    final catalog = TitleCatalogScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Account',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Titles backup to your Orbium account so they follow you to another device.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          session.signedInLabel,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (catalog.lastCloudError != null) ...[
          const SizedBox(height: 8),
          Text(
            catalog.lastCloudError!,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              key: const ValueKey<String>('sync-cloud-catalog-button'),
              onPressed: session.busy
                  ? null
                  : () => _sync(context, session, catalog),
              child: const Text('Sync now'),
            ),
            TextButton(
              key: const ValueKey<String>('sign-out-cloud-button'),
              onPressed: session.busy ? null : () => session.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
        if (session.lastError != null) ...[
          const SizedBox(height: 8),
          Text(
            session.lastError!,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _sync(
    BuildContext context,
    CloudSession session,
    TitleCatalog catalog,
  ) async {
    try {
      await session.runBusy(() => catalog.syncToCloud());
    } on Object {
      // lastError already set on the session
    }
  }
}

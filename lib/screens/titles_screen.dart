import 'package:flutter/material.dart';

import 'package:release_status/models/release_title.dart';
import 'package:release_status/state/title_catalog.dart';
import 'package:release_status/widgets/title_card.dart';

class TitlesScreen extends StatefulWidget {
  const TitlesScreen({
    super.key,
    required this.onOpenTitle,
    required this.onAddTitle,
  });

  final ValueChanged<ReleaseTitle> onOpenTitle;
  final VoidCallback onAddTitle;

  @override
  State<TitlesScreen> createState() => _TitlesScreenState();
}

class _TitlesScreenState extends State<TitlesScreen> {
  String? _contentFilter;

  List<ReleaseTitle> _visibleTitles(List<ReleaseTitle> titles) {
    final filter = _contentFilter;
    if (filter == null) {
      return titles;
    }
    return [
      for (final title in titles)
        if (title.contentType == filter) title,
    ];
  }

  void _selectFilter(String type) {
    setState(() {
      _contentFilter = _contentFilter == type ? null : type;
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = TitleCatalogScope.of(context).titles;
    final visible = _visibleTitles(titles);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    return ColoredBox(
      color: colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isCompact ? 20 : 32,
          isCompact ? 8 : 28,
          isCompact ? 20 : 32,
          isCompact ? 96 : 40,
        ),
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
                      Text(
                        'Your Titles',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A private catalog of titles you own or control. Pin any of them to the dashboard.',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
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
                ChoiceChip(
                  key: const ValueKey<String>('content-filter-Movie'),
                  label: const Text('Movie'),
                  selected: _contentFilter == 'Movie',
                  onSelected: (_) => _selectFilter('Movie'),
                ),
                ChoiceChip(
                  key: const ValueKey<String>('content-filter-TV Series'),
                  label: const Text('TV Series'),
                  selected: _contentFilter == 'TV Series',
                  onSelected: (_) => _selectFilter('TV Series'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (titles.isEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  child: Column(
                    children: [
                      Text(
                        'No titles yet',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This is a private list of titles you own or control. Add one to start tracking licensed platforms.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: widget.onAddTitle,
                        child: const Text('Add Title'),
                      ),
                    ],
                  ),
                ),
              )
            else if (visible.isEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  child: Text(
                    _contentFilter == 'Movie'
                        ? 'No movies in Your Titles.'
                        : 'No TV series in Your Titles.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else
              for (final title in visible) ...[
                TitleCard(
                  title: title,
                  onViewStatus: () => widget.onOpenTitle(title),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            Text(
              'Stored on this device  ·  Not a public catalog',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

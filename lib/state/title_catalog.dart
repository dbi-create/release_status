import 'package:flutter/material.dart';

import 'package:release_status/data/demo_data.dart';
import 'package:release_status/models/platform_status.dart';
import 'package:release_status/models/release_title.dart';

const List<Color> _placeholderColors = [
  Color(0xFF3A4A63),
  Color(0xFF4A5340),
  Color(0xFF2F4A4E),
  Color(0xFF5A3E48),
  Color(0xFF3E4A5A),
];

/// In-memory collection of the user's titles for this prototype session.
class TitleCatalog extends ChangeNotifier {
  TitleCatalog({List<ReleaseTitle>? initialTitles})
    : _titles = List<ReleaseTitle>.from(initialTitles ?? demoTitles);

  final List<ReleaseTitle> _titles;
  int _createdCount = 0;

  List<ReleaseTitle> get titles => List<ReleaseTitle>.unmodifiable(_titles);

  int get totalTitleCount => _titles.length;

  int get livePlatformCount =>
      _titles.fold<int>(0, (sum, title) => sum + title.livePlatformCount);

  int get waitingPlatformCount =>
      _titles.fold<int>(0, (sum, title) => sum + title.waitingPlatformCount);

  ReleaseTitle? titleById(String id) {
    for (final title in _titles) {
      if (title.id == id) {
        return title;
      }
    }
    return null;
  }

  ReleaseTitle addTitle({
    required String name,
    required String contentType,
    required int releaseYear,
    required List<String> platformNames,
  }) {
    _createdCount += 1;
    final title = ReleaseTitle(
      id: 'title-$_createdCount',
      name: name,
      releaseYear: releaseYear,
      contentType: contentType,
      placeholderColor:
          _placeholderColors[_titles.length % _placeholderColors.length],
      platforms: [
        for (final platformName in platformNames)
          PlatformStatus.waiting(platformName),
      ],
    );
    _titles.add(title);
    notifyListeners();
    return title;
  }

  void updateTitle(ReleaseTitle title) {
    final index = _titles.indexWhere((item) => item.id == title.id);
    if (index < 0) {
      return;
    }
    _titles[index] = title;
    notifyListeners();
  }

  void removeTitle(String id) {
    _titles.removeWhere((title) => title.id == id);
    notifyListeners();
  }
}

class TitleCatalogScope extends InheritedNotifier<TitleCatalog> {
  const TitleCatalogScope({
    super.key,
    required TitleCatalog catalog,
    required super.child,
  }) : super(notifier: catalog);

  static TitleCatalog of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TitleCatalogScope>();
    assert(scope != null, 'TitleCatalogScope not found in context');
    return scope!.notifier!;
  }
}

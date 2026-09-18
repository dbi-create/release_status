import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/monitoring/availability_monitor.dart';
import 'package:release_status/monitoring/listing_url_verifier.dart';
import 'package:release_status/monitoring/monitoring_result.dart';
import 'package:release_status/monitoring/title_identity.dart';
import 'package:release_status/monitoring/title_lookup.dart';

void main() {
  testWidgets('invalid empty form cannot save', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-title-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Title'), findsWidgets);
    expect(find.text('Enter a title name.'), findsOneWidget);
    expect(find.text('Select Movie or TV Series.'), findsOneWidget);
    expect(find.text('Enter a four-digit release year.'), findsOneWidget);
  });

  testWidgets('a valid title can be added and pinned to the dashboard', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);

    expect(find.text('Harbor Light'), findsNothing);

    await _openYourTitles(tester);
    expect(find.text('Harbor Light'), findsOneWidget);

    await _openTitleById(tester, 'title-1');
    await tester.tap(find.byKey(const ValueKey<String>('pin-title-button')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unpin Title'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Harbor Light'), findsOneWidget);
    expect(find.text('LIVE PLATFORMS: 2'), findsWidgets);
    expect(find.text('NOT LIVE: 0'), findsNothing);
  });

  testWidgets('added title appears under Your Titles', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);

    await _openYourTitles(tester);

    expect(find.text('Harbor Light'), findsOneWidget);
    expect(find.text('MARKED'), findsOneWidget);
  });

  testWidgets('newly added platforms become live after the listing URL checks out', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);
    await _openYourTitles(tester);

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-title-1'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    expect(find.text('2 of 2 platforms live', findRichText: true), findsWidgets);
    expect(find.textContaining('Channel Alpha'), findsOneWidget);
    expect(find.textContaining('Channel Beta'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.textContaining('Added Manually'), findsWidgets);
  });

  testWidgets('manual add platform requires a listing URL', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('title-name-field')),
      'Harbor Light',
    );
    await _selectCorrectTitle(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('add-manual-channel-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('platform-name-field')),
      'Relay',
    );
    await tester.tap(find.byKey(const ValueKey<String>('add-platform-button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a public http or https listing URL.'), findsOneWidget);
    expect(find.text('Relay'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
  });

  testWidgets('duplicate platform names are rejected case-insensitively', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('title-name-field')),
      'Harbor Light',
    );
    await _selectCorrectTitle(tester);
    await _enterPlatform(tester, 'Tubi');
    await _enterPlatform(tester, ' tubi');

    expect(
      find.text('That platform is already listed for this title.'),
      findsOneWidget,
    );
    expect(find.text('Tubi'), findsOneWidget);
  });

  testWidgets('title can be edited', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);
    await _openYourTitles(tester);

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-title-1'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('edit-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Title'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('title-name-field')),
      'Harbor Light Revised',
    );
    await _enterPlatform(tester, 'Channel Gamma');

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-title-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('Harbor Light Revised'), findsWidgets);
    expect(find.text('3 of 3 platforms live', findRichText: true), findsWidgets);
    expect(find.textContaining('Channel Gamma'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
  });

  testWidgets('title deletion requires confirmation', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);
    await _openYourTitles(tester);

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-title-1'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete-title-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Remove Harbor Light from ReleaseStatus?'),
      findsOneWidget,
    );
    expect(
      find.text('This removes the title from this device.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cancel-delete-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Harbor Light'), findsWidgets);
    expect(find.textContaining('Channel Alpha'), findsOneWidget);
  });

  testWidgets('confirmed deletion removes the title', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);
    await _openYourTitles(tester);

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-title-1'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('delete-title-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Harbor Light'), findsNothing);
    expect(find.text('MARKED'), findsOneWidget);
  });

  testWidgets('editing a title preserves existing platform status', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openYourTitles(tester);

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-ashen-field'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('1 of 3 platforms live', findRichText: true), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('edit-title-button')));
    await tester.pumpAndSettle();

    await _enterPlatform(tester, 'Channel Zeta');

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-title-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('2 of 4 platforms live', findRichText: true), findsWidgets);
    expect(find.textContaining('Platform One'), findsOneWidget);
    expect(find.textContaining('Channel Zeta'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('NOT LIVE'), findsWidgets);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ReleaseStatusApp(
      availabilityMonitor: _HarborTitleLookup(),
      listingUrlChecker: _acceptListingUrl,
    ),
  );
}

Future<void> _openYourTitles(WidgetTester tester) async {
  await tester.tap(find.text('Your Titles').first);
  await tester.pumpAndSettle();
}

Future<void> _openTitleById(WidgetTester tester, String id) async {
  final viewStatus = find.byKey(ValueKey<String>('view-status-$id'));
  await tester.ensureVisible(viewStatus);
  await tester.tap(viewStatus);
  await tester.pumpAndSettle();
}

Future<void> _addValidTitle(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey<String>('title-name-field')),
    'Harbor Light',
  );
  await tester.tap(find.byKey(const ValueKey<String>('content-type-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Movie').last);
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey<String>('release-year-field')),
    '2022',
  );
  await _selectCorrectTitle(tester);
  await _enterPlatform(tester, 'Channel Alpha');
  await _enterPlatform(tester, 'Channel Beta');

  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('save-title-button')),
  );
  await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
  await tester.pumpAndSettle();
}

Future<void> _selectCorrectTitle(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('find-title-matches-button')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('title-match-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Harbor Light  ·  Movie  ·  2022').last);
  await tester.pumpAndSettle();
}

Future<void> _enterPlatform(WidgetTester tester, String name) async {
  final openDialog = find.byKey(
    const ValueKey<String>('add-manual-channel-button'),
  );
  await tester.ensureVisible(openDialog);
  await tester.tap(openDialog);
  await tester.pumpAndSettle();
  final field = find.byKey(const ValueKey<String>('platform-name-field'));
  final urlField = find.byKey(const ValueKey<String>('platform-listing-url-field'));
  final button = find.byKey(const ValueKey<String>('add-platform-button'));
  await tester.enterText(field, name);
  await tester.enterText(
    urlField,
    'https://example.invalid/${name.trim().toLowerCase().replaceAll(' ', '-')}',
  );
  await tester.pump();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<ListingUrlCheckResult> _acceptListingUrl({
  required String titleName,
  required String url,
}) async {
  return ListingUrlCheckResult.verified(normalizedUrl: url.trim());
}

class _HarborTitleLookup implements AvailabilityMonitor, TitleLookup {
  @override
  bool get isConfigured => true;

  @override
  String get sourceId => 'test-lookup';

  @override
  String get displayName => 'Test lookup';

  @override
  Future<List<TitleLookupMatch>> searchByName({
    required String name,
    String? contentType,
    int? year,
  }) async {
    if (name.trim().toLowerCase() != 'harbor light') {
      return const [];
    }
    return const [
      TitleLookupMatch(
        name: 'Harbor Light',
        contentType: 'Movie',
        year: 2022,
      ),
    ];
  }

  @override
  Future<MonitoringResult> check({
    required TitleIdentity title,
    required String licensedPlatform,
  }) async {
    return MonitoringResult.unconfigured(licensedPlatform);
  }
}

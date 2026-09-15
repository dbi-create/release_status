import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';

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

    expect(find.text('Add Your Title'), findsOneWidget);
    expect(find.text('Enter a title name.'), findsOneWidget);
    expect(find.text('Select Movie or TV Series.'), findsOneWidget);
    expect(find.text('Enter a four-digit release year.'), findsOneWidget);
    expect(find.text('Add at least one licensed platform.'), findsOneWidget);
  });

  testWidgets('a valid title can be added and appears on the dashboard', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);

    expect(find.text('Harbor Light'), findsOneWidget);
    expect(find.text('2 licensed platforms'), findsWidgets);
    expect(find.text('2 waiting'), findsOneWidget);
  });

  testWidgets('added title appears under My Titles', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);

    await tester.tap(find.text('My Titles'));
    await tester.pumpAndSettle();

    expect(find.text('Harbor Light'), findsOneWidget);
    expect(find.text('MARKED'), findsOneWidget);
  });

  testWidgets('newly added platforms default to WAITING', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-title-1'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    expect(find.text('0 of 2 platforms live'), findsWidgets);
    expect(find.text('Channel Alpha'), findsOneWidget);
    expect(find.text('Channel Beta'), findsOneWidget);
    expect(find.text('WAITING'), findsWidgets);
    expect(find.text('Not yet detected'), findsWidgets);
    expect(find.text('Monitoring has not started'), findsWidgets);
    expect(
      find.text(
        'Monitoring has not started for this title. No availability check has occurred.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('First Detected'), findsNothing);
  });

  testWidgets('duplicate platform names are rejected case-insensitively', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();

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
    expect(find.text('0 of 3 platforms live'), findsWidgets);
    expect(find.text('Channel Gamma'), findsOneWidget);
    expect(find.text('WAITING'), findsWidgets);
  });

  testWidgets('title deletion requires confirmation', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);

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
      find.text(
        'This removes the title from this local prototype. It is not saved anywhere else.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cancel-delete-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Harbor Light'), findsWidgets);
    expect(find.text('Channel Alpha'), findsOneWidget);
  });

  testWidgets('confirmed deletion removes the title', (tester) async {
    await _pumpApp(tester);

    await _addValidTitle(tester);

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

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-ashen-field'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('1 of 3 platforms live'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('edit-title-button')));
    await tester.pumpAndSettle();

    await _enterPlatform(tester, 'Channel Zeta');

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-title-button')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('1 of 4 platforms live'), findsWidgets);
    expect(find.text('Platform One'), findsOneWidget);
    expect(find.text('Channel Zeta'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('WAITING'), findsWidgets);
    expect(find.text('Monitoring has not started'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const ReleaseStatusApp());
}

Future<void> _addValidTitle(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey<String>('title-name-field')),
    'Harbor Light',
  );
  await tester.tap(find.byKey(const ValueKey<String>('content-type-Movie')));
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey<String>('release-year-field')),
    '2022',
  );
  await _enterPlatform(tester, 'Channel Alpha');
  await _enterPlatform(tester, 'Channel Beta');

  await tester.ensureVisible(
    find.byKey(const ValueKey<String>('save-title-button')),
  );
  await tester.tap(find.byKey(const ValueKey<String>('save-title-button')));
  await tester.pumpAndSettle();
}

Future<void> _enterPlatform(WidgetTester tester, String name) async {
  final field = find.byKey(const ValueKey<String>('platform-name-field'));
  final button = find.byKey(const ValueKey<String>('add-platform-button'));
  await tester.ensureVisible(field);
  await tester.enterText(field, name);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
}

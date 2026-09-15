import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';

void main() {
  testWidgets('dashboard shows personal branding and MARKED', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    expect(find.text('ReleaseStatus'), findsWidgets);
    expect(
      find.text('Your titles. Your platforms. Your status.'),
      findsWidgets,
    );
    expect(find.text('Your Releases'), findsOneWidget);
    expect(find.text('MARKED'), findsOneWidget);
    expect(find.text('5 licensed platforms'), findsOneWidget);
    expect(find.text('3 live  ·  2 waiting'), findsOneWidget);
    expect(find.text('TOTAL TITLES'), findsOneWidget);
    expect(find.text('LIVE PLATFORMS'), findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);
    expect(find.text('STATUS CHANGES'), findsOneWidget);
    expect(
      find.text('Static demo number — not live monitoring'),
      findsOneWidget,
    );
  });

  testWidgets('Add Title can be opened', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Your Title'), findsOneWidget);
    expect(
      find.text(
        'Add a movie or TV show you own, produce, distribute, or control.',
      ),
      findsOneWidget,
    );
    expect(find.text('Licensed Platforms'), findsOneWidget);
  });

  testWidgets('My Titles navigation shows the private catalog', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    await tester.tap(find.text('My Titles'));
    await tester.pumpAndSettle();

    expect(find.text('Your Titles'), findsWidgets);
    expect(find.text('MARKED'), findsOneWidget);
    expect(find.text('ASHEN FIELD'), findsOneWidget);
    expect(find.text('NORTHWATER'), findsOneWidget);
    expect(
      find.text(
        'A private dashboard for titles you own or control. This is not a public catalog.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('MARKED opens title detail with platform statuses', (
    tester,
  ) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    final viewStatus = find.byKey(const ValueKey<String>('view-status-marked'));
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    expect(find.text('Platform Status'), findsOneWidget);
    expect(find.text('3 of 5 platforms live'), findsWidgets);
    expect(find.text('Platform One'), findsOneWidget);
    expect(find.text('Platform Two'), findsOneWidget);
    expect(find.text('Platform Three'), findsOneWidget);
    expect(find.text('Platform Four'), findsOneWidget);
    expect(find.text('Platform Five'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('WAITING'), findsWidgets);
    expect(find.text('Not yet detected'), findsWidgets);
    expect(find.textContaining('Last Checked (local demo data)'), findsWidgets);
  });

  testWidgets('wide layout keeps the desktop sidebar', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());

    expect(find.text('Local Prototype'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('My Titles'), findsOneWidget);
  });
}

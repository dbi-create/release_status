import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/screens/title_detail_screen.dart';
import 'package:release_status/widgets/app_sidebar.dart';

void main() {
  testWidgets('dashboard shows personal branding and MARKED', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    expect(find.text('RELEASE STATUS'), findsOneWidget);
    expect(find.text('YOUR TITLES'), findsOneWidget);
    expect(find.text('YOUR PLATFORMS'), findsOneWidget);
    expect(find.text('YOUR STATUS'), findsOneWidget);
    expect(find.text('PINNED (1)'), findsOneWidget);
    expect(find.text('MARKED'), findsOneWidget);
    expect(find.text('LIVE PLATFORMS: 0'), findsOneWidget);
    expect(find.text('ADDED TITLES'), findsOneWidget);
    expect(find.text('LIVE CHANNELS'), findsOneWidget);
    expect(find.text('NOT LIVE: 5'), findsNothing);
    expect(find.text('NOT LIVE: 6'), findsNothing);
    expect(find.text('Overview'), findsNothing);
    expect(find.byTooltip('Check All Titles'), findsOneWidget);
    expect(find.text('Export status report'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('notifications-button')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('settings-button')), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing);
    expect(find.byKey(const ValueKey<String>('add-title-button')), findsOneWidget);

    final checkAllRect = tester.getRect(
      find.byKey(const ValueKey<String>('check-all-titles-button')),
    );
    final notificationsRect = tester.getRect(
      find.byKey(const ValueKey<String>('notifications-button')),
    );
    final settingsRect = tester.getRect(
      find.byKey(const ValueKey<String>('settings-button')),
    );
    expect(notificationsRect.left, greaterThan(checkAllRect.left));
    expect(settingsRect.left, greaterThanOrEqualTo(notificationsRect.left));
  });

  testWidgets('Notifications opens attention items in a popup', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    await tester.tap(find.byKey(const ValueKey<String>('notifications-button')));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Never checked'), findsNothing);
    expect(find.text('MARKED has not been checked yet'), findsNothing);
    expect(find.text('No notifications right now.'), findsOneWidget);
    expect(find.text('Updated: not yet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('notifications-updated-label')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('close-notifications-button')));
    await tester.pumpAndSettle();
    expect(find.text('Never checked'), findsNothing);
  });

  testWidgets('Add Title can be opened', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    await tester.tap(find.byKey(const ValueKey<String>('add-title-button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Title'), findsWidgets);
    expect(
      find.text(
        'Add a movie or TV show you own, produce, distribute, or control.',
      ),
      findsNothing,
    );
    expect(find.text('Licensed Platforms'), findsNothing);
  });

  testWidgets('Your Titles navigation shows the private catalog', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp());

    await tester.tap(find.text('Your Titles'));
    await tester.pumpAndSettle();

    expect(find.text('Your Titles'), findsWidgets);
    expect(find.text('MARKED'), findsOneWidget);
    expect(find.text('ASHEN FIELD'), findsOneWidget);
    expect(find.text('NORTHWATER'), findsOneWidget);
    expect(find.text('Movie'), findsWidgets);
    expect(find.text('TV Series'), findsWidgets);
    expect(
      find.text(
        'A private catalog of titles you own or control. Pin any of them to the dashboard.',
      ),
      findsNothing,
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
    expect(find.byTooltip('Recheck Platform Status'), findsOneWidget);
    expect(find.text('0 of 5 platforms live', findRichText: true), findsWidgets);
    expect(find.textContaining('Amazon'), findsWidgets);
    expect(find.textContaining('PLEX'), findsOneWidget);
    expect(find.textContaining('Fawesome'), findsOneWidget);
    expect(find.textContaining('Ofive+'), findsOneWidget);
    expect(find.textContaining('Relay'), findsOneWidget);
    expect(find.text('NOT LIVE'), findsWidgets);
    expect(find.textContaining('Added Manually'), findsWidgets);
    expect(find.textContaining('Monitoring has not started'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(TitleDetailScreen),
        matching: find.text('LIVE'),
      ),
      findsNothing,
    );
  });

  testWidgets('wide layout keeps the desktop sidebar', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());

    expect(find.text('Local Prototype'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Your Titles'), findsOneWidget);
  });

  testWidgets('Your Titles can filter by Movie and TV Series', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());
    await tester.tap(find.text('Your Titles'));
    await tester.pumpAndSettle();

    expect(find.text('MARKED'), findsOneWidget);
    expect(find.text('ASHEN FIELD'), findsOneWidget);
    expect(find.text('NORTHWATER'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('content-filter-Movie')));
    await tester.pumpAndSettle();
    expect(find.text('ASHEN FIELD'), findsOneWidget);
    expect(find.text('MARKED'), findsNothing);
    expect(find.text('NORTHWATER'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('content-filter-TV Series')),
    );
    await tester.pumpAndSettle();
    expect(find.text('MARKED'), findsOneWidget);
    expect(find.text('NORTHWATER'), findsOneWidget);
    expect(find.text('ASHEN FIELD'), findsNothing);
  });

  testWidgets('Your Titles View Status opens title detail', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());
    await tester.tap(find.text('Your Titles'));
    await tester.pumpAndSettle();

    final viewStatus = find.byKey(const ValueKey<String>('view-status-ashen-field'));
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    expect(find.byType(TitleDetailScreen), findsOneWidget);
    expect(find.text('ASHEN FIELD'), findsWidgets);
    expect(find.text('Platform Status'), findsOneWidget);
    expect(find.text('1 of 3 platforms live', findRichText: true), findsWidgets);
  });

  testWidgets('Pin Title from Your Titles shows the title on the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());
    await tester.tap(find.text('Your Titles'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Pin Title'), findsWidgets);
    final pin = find.byKey(const ValueKey<String>('pin-title-ashen-field'));
    await tester.ensureVisible(pin);
    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unpin Title'), findsWidgets);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('ASHEN FIELD'), findsOneWidget);
    expect(find.byTooltip('Unpin Title'), findsWidgets);
  });

  testWidgets('Your Titles actions sit on the right of each card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());
    await tester.tap(find.text('Your Titles'));
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('ASHEN FIELD').first);
    final pin = tester.getRect(
      find.byKey(const ValueKey<String>('pin-title-ashen-field')),
    );
    final viewStatus = tester.getRect(
      find.byKey(const ValueKey<String>('view-status-ashen-field')),
    );
    final delete = tester.getRect(
      find.byKey(const ValueKey<String>('delete-title-ashen-field')),
    );

    expect(pin.left, greaterThan(title.right));
    expect(delete.left, greaterThan(pin.right - 1));
    expect((delete.top - pin.top).abs(), lessThan(8));
    expect(viewStatus.top, greaterThan(pin.bottom - 1));
    expect(find.text('View Title'), findsWidgets);
    expect(find.text('View Status'), findsNothing);
    expect(find.text('Unpin Title'), findsNothing);
    expect(find.text('Delete Title'), findsNothing);
  });

  testWidgets('Your Titles Delete Title asks before removing', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());
    await tester.tap(find.text('Your Titles'));
    await tester.pumpAndSettle();

    final delete = find.byKey(const ValueKey<String>('delete-title-ashen-field'));
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(
      find.text('Remove ASHEN FIELD from ReleaseStatus?'),
      findsOneWidget,
    );
    expect(
      find.text('This removes the title from this device.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('cancel-delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('ASHEN FIELD'), findsOneWidget);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-delete-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ASHEN FIELD'), findsNothing);
    expect(find.text('NORTHWATER'), findsOneWidget);
  });

  testWidgets('phone layout uses bottom navigation without a shell AppBar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ReleaseStatusApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('RELEASE STATUS'), findsOneWidget);
    expect(find.text('YOUR TITLES'), findsOneWidget);
    expect(find.text('YOUR PLATFORMS'), findsOneWidget);
    expect(find.text('YOUR STATUS'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('check-all-titles-button')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('notifications-button')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('settings-button')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('add-title-button')), findsOneWidget);
    expect(find.text('Add Title'), findsOneWidget);

    await tester.tap(find.text('Your Titles'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey<String>('add-title-button')), findsOneWidget);

    final viewStatus = find.byKey(
      const ValueKey<String>('view-status-ashen-field'),
    );
    await tester.ensureVisible(viewStatus);
    await tester.tap(viewStatus);
    await tester.pumpAndSettle();

    expect(find.byType(TitleDetailScreen), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Platform Status'), findsOneWidget);
  });
}

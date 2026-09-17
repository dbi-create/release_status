import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/screens/login_screen.dart';

void main() {
  testWidgets('login screen offers email, Google, and Apple', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: LoginScreen(onAuthenticated: () async {}),
        ),
      );

      expect(find.text('RELEASE STATUS'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('login-toggle-mode-button')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('login-toggle-mode-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('login-toggle-mode-button')),
      );
      await tester.pump();
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('Sign up to back up your titles.'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

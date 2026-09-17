import 'package:flutter_test/flutter_test.dart';

import 'package:release_status/app.dart';
import 'package:release_status/screens/splash_screen.dart';

void main() {
  testWidgets('boot splash stays up for 5 seconds', (tester) async {
    await tester.pumpWidget(const ReleaseStatusApp(showBootSplash: true));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('PINNED (1)'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('PINNED (1)'), findsOneWidget);
  });
}

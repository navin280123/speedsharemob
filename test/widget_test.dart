// This is a basic Flutter widget test for SpeedShare mobile app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedsharemob/main.dart';

void main() {
  testWidgets('App renders properly', (WidgetTester tester) async {
    // Setup mock shared preferences
    SharedPreferences.setMockInitialValues({
      'darkMode': false,
      'deviceName': 'Test Device',
    });
    
    // Build our app and trigger a frame
    await tester.pumpWidget(const MyApp(darkMode: false));
    await tester.pumpAndSettle(); // Wait for animations to complete

    // Verify that the app title appears
    expect(find.text('SpeedShare'), findsOneWidget);
    
    // Verify that the main navigation items are present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    
    // Test navigation
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Select Files'), findsWidgets);
    
    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();
    expect(find.text('Receive Files'), findsOneWidget);
    
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    
    // Go back to home
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SpeedShare'), findsOneWidget);

  });
}
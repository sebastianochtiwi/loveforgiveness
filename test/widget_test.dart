// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:love_forgiveness_app/main.dart';

void main() {
  testWidgets('Game starts with welcome message', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the welcome text is displayed
    expect(find.textContaining('Welcome to the Love and Forgiveness Game!'), findsOneWidget);
    expect(find.text("Yes, let's begin!"), findsOneWidget);
  });

  testWidgets('Game navigation works', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Tap the start button
    await tester.tap(find.text("Yes, let's begin!"));
    await tester.pump();

    // Verify we moved to scene 1
    expect(find.textContaining('Scene 1: You have a close friend'), findsOneWidget);
    expect(find.text('A) Confront angrily'), findsOneWidget);
    expect(find.text('B) Talk calmly'), findsOneWidget);
  });
}

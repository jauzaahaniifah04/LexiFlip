import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Welcome page offers registration and login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));

    expect(find.text('LexiFlip'), findsOneWidget);
    expect(find.text('DAFTAR AKUN'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('Startup failure explains the error and offers retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupErrorPage(
          settings: AppSettingsController(),
          error: StateError('Database tidak tersedia'),
        ),
      ),
    );

    expect(find.text('LexiFlip belum dapat dimulai.'), findsOneWidget);
    expect(find.textContaining('Database tidak tersedia'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}

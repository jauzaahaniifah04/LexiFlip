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
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App shows a loading screen while startup is pending', (
    WidgetTester tester,
  ) async {
    final startup = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: LexiFlipApp(
          settings: AppSettingsController(),
          startup: startup.future,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('LexiFlip sedang disiapkan...'), findsOneWidget);
  });

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
      MaterialApp(home: StartupErrorPage(settings: AppSettingsController())),
    );

    expect(find.text('LexiFlip belum dapat dimulai.'), findsOneWidget);
    expect(
      find.textContaining('Periksa penyimpanan perangkat'),
      findsOneWidget,
    );
    expect(find.textContaining('Database tidak tersedia'), findsNothing);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('Settings opens the About page and back returns to settings', (
    WidgetTester tester,
  ) async {
    final settings = AppSettingsController();
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(settings: settings)),
    );

    expect(find.text('Tentang Aplikasi'), findsOneWidget);
    await tester.tap(find.text('Tentang Aplikasi'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byIcon(Icons.style_rounded)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
    );
    expect(find.text('LexiFlip'), findsOneWidget);
    expect(
      find.text('Aplikasi Pembelajaran Dasar Pemrograman C++'),
      findsOneWidget,
    );
    expect(
      find.textContaining('materi pembelajaran, flashcard, dan latihan kode'),
      findsOneWidget,
    );
    expect(find.text('Teknologi yang Digunakan'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('SQLite'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsOneWidget);
  });
}

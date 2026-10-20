import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_application_1/database/database_platform.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDatabasePlatform();
    if (!Platform.isWindows) {
      databaseFactory = databaseFactoryFfi;
    }
  });

  test(
    'initialization is shared and database CRUD persists after reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('lexiflip-db-');
      final databasePath = p.join(directory.path, 'lexiflip.db');
      final helper = DatabaseHelper.forTesting(databasePath);

      try {
        await Future.wait([helper.initDatabase(), helper.initDatabase()]);
        expect(
          Sqflite.firstIntValue(
            await helper.database.rawQuery('SELECT COUNT(*) FROM bab'),
          ),
          5,
        );

        await helper.saveAppPreference(key: 'theme_mode', value: 'dark');
        expect((await helper.getAppPreferences())['theme_mode'], 'dark');
        await helper.saveAppPreference(key: 'theme_mode', value: 'light');
        expect((await helper.getAppPreferences())['theme_mode'], 'light');
        await helper.database.delete(
          'preferensi_aplikasi',
          where: 'kunci = ?',
          whereArgs: ['theme_mode'],
        );
        expect(
          (await helper.getAppPreferences()).containsKey('theme_mode'),
          isFalse,
        );

        final userId = await helper.daftarAkun(
          nama: 'Pengguna Tes',
          username: 'tes',
          password: 'password123',
        );
        expect(userId, greaterThan(0));
        await helper.updateNamaPengguna(nama: 'Nama Baru');
        expect((await helper.getPenggunaAktif())?['nama'], 'Nama Baru');
        await helper.logout();
        expect(await helper.cekSesiLogin(), isNull);

        await helper.database.close();
        final reopened = DatabaseHelper.forTesting(databasePath);
        await reopened.initDatabase();
        expect((await reopened.getPenggunaAktif()), isNull);
        expect(
          Sqflite.firstIntValue(
            await reopened.database.rawQuery('SELECT COUNT(*) FROM pengguna'),
          ),
          1,
        );
        await reopened.database.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'version 4 migration keeps existing data and adds materi progress',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lexiflip-migration-',
      );
      final databasePath = p.join(directory.path, 'lexiflip.db');

      try {
        final oldDatabase = await databaseFactory.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 4,
            onCreate: (db, version) async {
              await db.execute('''
              CREATE TABLE bab (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                judul TEXT NOT NULL,
                deskripsi TEXT NOT NULL,
                urutan INTEGER NOT NULL
              )
            ''');
              await db.insert('bab', {
                'judul': 'Data lama',
                'deskripsi': 'Tetap dipertahankan',
                'urutan': 1,
              });
            },
          ),
        );
        await oldDatabase.close();

        final helper = DatabaseHelper.forTesting(databasePath);
        await helper.initDatabase();

        final bab = await helper.database.query('bab');
        expect(bab.single['judul'], 'Data lama');
        final progressTable = await helper.database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
          ['log_materi'],
        );
        expect(progressTable, hasLength(1));
        await helper.database.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

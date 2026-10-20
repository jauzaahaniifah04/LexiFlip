import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'code_auto_indent_formatter.dart';
import 'code_evaluator.dart';
import 'database/database_platform.dart';

final ValueNotifier<int> progressDataVersion = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appSettings = AppSettingsController();
  Object? initializationError;
  try {
    await DatabaseHelper.instance.initDatabase();
    await appSettings.load();
  } catch (error, stackTrace) {
    _logDatabaseError(
      'Gagal menginisialisasi database atau preferensi',
      error,
      stackTrace,
    );
    initializationError = error;
  }

  runApp(
    LexiFlipApp(
      settings: appSettings,
      initializationError: initializationError,
    ),
  );
}

void _logDatabaseError(String operation, Object error, StackTrace stackTrace) {
  debugPrint('$operation: $error\n$stackTrace');
}

Future<T> _withDatabaseErrorLogging<T>(
  String operation,
  Future<T> Function() run,
) async {
  try {
    return await run();
  } catch (error, stackTrace) {
    _logDatabaseError(operation, error, stackTrace);
    rethrow;
  }
}

// ============================================================
// DATABASE
// ============================================================

class DatabaseHelper {
  DatabaseHelper._() : _databasePathOverride = null;

  @visibleForTesting
  DatabaseHelper.forTesting(String databasePath)
    : _databasePathOverride = databasePath;

  static final DatabaseHelper instance = DatabaseHelper._();

  static int userId = 0;
  static const String databaseName = 'lexiflip.db';

  final String? _databasePathOverride;

  Database? _database;
  Future<void>? _initialization;

  Future<void> initDatabase() {
    return _initialization ??= _openDatabase().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _initialization = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _openDatabase() async {
    await initializeDatabasePlatform();
    final databasePath =
        _databasePathOverride ?? await databasePathFor(databaseName);

    _database = await openDatabase(
      databasePath,
      version: 5,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDatabase(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _ensureAuthSchema(db);
        }
        if (oldVersion < 4) {
          await _createAppPreferencesTable(db);
        }
        if (oldVersion < 5) {
          await _createMateriProgressTable(db);
        }
      },
    );
  }

  Future<void> _createAppPreferencesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS preferensi_aplikasi (
        kunci TEXT PRIMARY KEY,
        nilai TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMateriProgressTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS log_materi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pengguna_id INTEGER NOT NULL,
        materi_id INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        UNIQUE (pengguna_id, materi_id)
      )
    ''');
  }

  Future<void> _ensureAuthSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pengguna (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        username TEXT,
        salt TEXT,
        password_hash TEXT
      )
    ''');

    final columns = await db.rawQuery('PRAGMA table_info(pengguna)');
    final columnNames = columns
        .map((column) => column['name'] as String)
        .toSet();

    if (!columnNames.contains('nama')) {
      await db.execute(
        "ALTER TABLE pengguna ADD COLUMN nama TEXT NOT NULL DEFAULT ''",
      );
    }
    if (!columnNames.contains('username')) {
      await db.execute('ALTER TABLE pengguna ADD COLUMN username TEXT');
    }
    if (!columnNames.contains('salt')) {
      await db.execute('ALTER TABLE pengguna ADD COLUMN salt TEXT');
    }
    if (!columnNames.contains('password_hash')) {
      await db.execute('ALTER TABLE pengguna ADD COLUMN password_hash TEXT');
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sesi_login (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        pengguna_id INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_pengguna_username
      ON pengguna(username)
    ''');
  }

  Future<void> _createTables(Database db) async {
    await _ensureAuthSchema(db);
    await _createAppPreferencesTable(db);
    await _createMateriProgressTable(db);

    await db.execute('''
      CREATE TABLE bab (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        judul TEXT NOT NULL,
        deskripsi TEXT NOT NULL,
        urutan INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE materi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bab_id INTEGER NOT NULL,
        judul TEXT NOT NULL,
        isi TEXT NOT NULL,
        contoh TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE flashcard (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bab_id INTEGER NOT NULL,
        pertanyaan TEXT NOT NULL,
        jawaban TEXT NOT NULL,
        contoh TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE latihan_kode (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bab_id INTEGER NOT NULL,
        instruksi TEXT NOT NULL,
        contoh TEXT NOT NULL,
        template TEXT NOT NULL,
        kunci TEXT NOT NULL,
        output TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE hasil_latihan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pengguna_id INTEGER NOT NULL,
        latihan_id INTEGER NOT NULL,
        kode TEXT NOT NULL,
        status TEXT NOT NULL,
        keterangan TEXT NOT NULL,
        tanggal TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE log_belajar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pengguna_id INTEGER NOT NULL,
        flashcard_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        tanggal TEXT NOT NULL
      )
    ''');
  }

  Future<Map<String, String>> getAppPreferences() async {
    final rows = await database.query('preferensi_aplikasi');
    return {
      for (final row in rows) row['kunci'] as String: row['nilai'] as String,
    };
  }

  Future<void> saveAppPreference({
    required String key,
    required String value,
  }) async {
    await database.insert('preferensi_aplikasi', {
      'kunci': key,
      'nilai': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<int>> getMateriSelesaiIds({required List<int> materiIds}) async {
    if (userId == 0 || materiIds.isEmpty) return {};

    final placeholders = List.filled(materiIds.length, '?').join(', ');
    final rows = await database.rawQuery(
      '''
      SELECT materi_id
      FROM log_materi
      WHERE pengguna_id = ?
        AND materi_id IN ($placeholders)
      ''',
      [userId, ...materiIds],
    );
    return rows.map((row) => row['materi_id'] as int).toSet();
  }

  Future<void> tandaiMateriSelesai({required int materiId}) async {
    if (userId == 0) {
      throw StateError('Tidak ada pengguna yang sedang login.');
    }

    await database.insert('log_materi', {
      'pengguna_id': userId,
      'materi_id': materiId,
      'tanggal': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    progressDataVersion.value++;
  }

  Future<void> _seedDatabase(Database db) async {
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM bab')) ??
        0;

    if (count > 0) return;

    const babData = [
      {
        'judul': 'Variabel',
        'deskripsi': 'Mempelajari variabel untuk menyimpan data.',
        'urutan': 1,
      },
      {
        'judul': 'Tipe Data',
        'deskripsi': 'Mengenal jenis data dasar dalam C++.',
        'urutan': 2,
      },
      {
        'judul': 'Percabangan',
        'deskripsi': 'Mempelajari if dan else.',
        'urutan': 3,
      },
      {
        'judul': 'Perulangan',
        'deskripsi': 'Mempelajari for dan while.',
        'urutan': 4,
      },
      {
        'judul': 'Struktur Data',
        'deskripsi': 'Mempelajari array sederhana.',
        'urutan': 5,
      },
    ];

    for (final bab in babData) {
      await db.insert('bab', bab);
    }

    const materi = [
      // BAB 1: VARIABEL
      {
        'bab_id': 1,
        'judul': '1. Pengertian Variabel',
        'isi': 'Variabel adalah tempat untuk menyimpan data di dalam program. Data tersebut disimpan menggunakan nama tertentu agar dapat dipanggil dan digunakan kembali. Dalam C++, variabel harus memiliki tipe data dan nama sebelum digunakan.',
        'contoh': 'int umur = 20;',
      },
      {
        'bab_id': 1,
        'judul': '2. Deklarasi Variabel',
        'isi': 'Deklarasi adalah proses mengenalkan variabel kepada program. Deklarasi dilakukan dengan menentukan tipe data dan nama variabel.',
        'contoh': 'int umur;\numur = 20;',
      },
      {
        'bab_id': 1,
        'judul': '3. Inisialisasi Variabel',
        'isi': 'Inisialisasi adalah pemberian nilai awal pada variabel. Nilai variabel dapat diubah selama program berjalan jika tipe datanya sesuai.',
        'contoh': 'int nilai = 80;\nnilai = 90;',
      },
      {
        'bab_id': 1,
        'judul': '4. Aturan Penamaan Variabel',
        'isi': 'Nama variabel dapat menggunakan huruf, angka, dan garis bawah. Nama tidak boleh diawali angka atau menggunakan kata kunci C++. Huruf besar dan kecil dibedakan.',
        'contoh': 'int nilaiSiswa = 90;\nint jumlah_barang = 5;',
      },
      {
        'bab_id': 1,
        'judul': '5. Konstanta',
        'isi': 'Konstanta adalah nilai yang tidak boleh diubah setelah ditetapkan. Kata kunci const digunakan untuk membuat konstanta.',
        'contoh': 'const double phi = 3.14159;',
      },

      // BAB 2: TIPE DATA
      {
        'bab_id': 2,
        'judul': '1. Pengertian Tipe Data',
        'isi': 'Tipe data menentukan jenis nilai yang dapat disimpan oleh variabel. Pemilihan tipe data membantu program mengolah data dengan benar.',
        'contoh': 'int umur = 20;\ndouble tinggi = 165.5;',
      },
      {
        'bab_id': 2,
        'judul': '2. Tipe Data Integer',
        'isi': 'Tipe int digunakan untuk menyimpan bilangan bulat, baik positif, negatif, maupun nol.',
        'contoh': 'int jumlahSiswa = 32;\nint suhu = -5;',
      },
      {
        'bab_id': 2,
        'judul': '3. Tipe Data Float dan Double',
        'isi': 'Float dan double digunakan untuk menyimpan bilangan pecahan. Double umumnya memiliki presisi lebih tinggi daripada float.',
        'contoh': 'float berat = 52.5f;\ndouble rataRata = 87.75;',
      },
      {
        'bab_id': 2,
        'judul': '4. Tipe Data Char dan String',
        'isi': 'Char menyimpan satu karakter dengan tanda petik tunggal. String menyimpan rangkaian karakter dengan tanda petik ganda. String memerlukan pustaka string.',
        'contoh':
            '#include <string>\nchar kelas = \'A\';\nstring nama = "Budi";',
      },
      {
        'bab_id': 2,
        'judul': '5. Tipe Data Boolean',
        'isi': 'Tipe bool menyimpan nilai logika true atau false. Tipe ini sering digunakan dalam percabangan dan perulangan.',
        'contoh': 'bool lulus = true;',
      },

      // BAB 3: PERCABANGAN
      {
        'bab_id': 3,
        'judul': '1. Pengertian Percabangan',
        'isi': 'Percabangan memungkinkan program memilih tindakan berdasarkan kondisi. Jika kondisi benar, blok kode dijalankan.',
        'contoh': 'if (nilai >= 75) {\n  cout << "Lulus";\n}',
      },
      {
        'bab_id': 3,
        'judul': '2. Percabangan if',
        'isi': 'Pernyataan if menjalankan blok kode hanya ketika kondisi bernilai benar. Jika kondisi salah, blok tersebut dilewati.',
        'contoh': 'if (umur >= 17) {\n  cout << "Boleh membuat KTP";\n}',
      },
      {
        'bab_id': 3,
        'judul': '3. Percabangan if-else',
        'isi': 'If-else menyediakan dua pilihan tindakan. If berjalan ketika kondisi benar, sedangkan else berjalan ketika kondisi salah.',
        'contoh': 'if (nilai >= 75) {\n  cout << "Lulus";\n} else {\n  cout << "Remedial";\n}',
      },
      {
        'bab_id': 3,
        'judul': '4. Percabangan else-if',
        'isi': 'Else-if digunakan untuk memeriksa beberapa kondisi secara berurutan. Jika tidak ada kondisi yang benar, blok else dapat dijalankan.',
        'contoh': 'if (nilai >= 90) {\n  cout << "A";\n} else if (nilai >= 80) {\n  cout << "B";\n} else {\n  cout << "C";\n}',
      },
      {
        'bab_id': 3,
        'judul': '5. Operator Logika',
        'isi': 'Operator && berarti dan, || berarti atau, sedangkan ! berarti bukan. Operator ini digunakan untuk menggabungkan atau membalik kondisi.',
        'contoh': 'if (nilai >= 75 && hadir >= 80) {\n  cout << "Lulus";\n}',
      },

      // BAB 4: PERULANGAN
      {
        'bab_id': 4,
        'judul': '1. Pengertian Perulangan',
        'isi': 'Perulangan digunakan untuk menjalankan perintah berkali-kali. Jenis yang umum dipelajari adalah for, while, dan do-while.',
        'contoh': 'for (int i = 0; i < 5; i++) {\n  cout << i << endl;\n}',
      },
      {
        'bab_id': 4,
        'judul': '2. Perulangan for',
        'isi': 'For cocok digunakan ketika jumlah pengulangan diketahui. Inisialisasi menentukan nilai awal, kondisi menentukan kapan perulangan berjalan, dan perubahan memperbarui penghitung.',
        'contoh': 'for (int i = 1; i <= 5; i++) {\n  cout << i << endl;\n}',
      },
      {
        'bab_id': 4,
        'judul': '3. Perulangan while',
        'isi': 'While memeriksa kondisi sebelum menjalankan kode. Jika kondisi awal salah, blok tidak dijalankan. Pastikan kondisi dapat berubah agar tidak terjadi perulangan tanpa akhir.',
        'contoh':
            'int i = 1;\nwhile (i <= 5) {\n  cout << i << endl;\n  i++;\n}',
      },
      {
        'bab_id': 4,
        'judul': '4. Perulangan do-while',
        'isi': 'Do-while menjalankan blok kode terlebih dahulu, kemudian memeriksa kondisi. Karena itu, kode dijalankan minimal satu kali.',
        'contoh':
            'int i = 1;\ndo {\n  cout << i << endl;\n  i++;\n} while (i <= 5);',
      },
      {
        'bab_id': 4,
        'judul': '5. Menghentikan Perulangan',
        'isi': 'Break menghentikan perulangan secara langsung. Continue melewati sisa perintah pada putaran saat ini dan melanjutkan putaran berikutnya.',
        'contoh': 'for (int i = 1; i <= 5; i++) {\n  if (i == 3) continue;\n  cout << i << endl;\n}',
      },

      // BAB 5: STRUKTUR DATA
      {
        'bab_id': 5,
        'judul': '1. Pengertian Array',
        'isi': 'Array adalah struktur data yang menyimpan sejumlah elemen dengan tipe data sama dalam satu nama variabel. Setiap elemen diakses menggunakan indeks.',
        'contoh': 'int angka[3] = {10, 20, 30};',
      },
      {
        'bab_id': 5,
        'judul': '2. Indeks Array',
        'isi': 'Indeks array C++ dimulai dari 0. Array berukuran 3 memiliki indeks 0, 1, dan 2. Mengakses indeks di luar batas array dapat menyebabkan perilaku tidak terduga.',
        'contoh': 'int angka[3] = {10, 20, 30};\ncout << angka[0]; // 10',
      },
      {
        'bab_id': 5,
        'judul': '3. Mengubah Elemen Array',
        'isi': 'Elemen array dapat dibaca atau diubah menggunakan indeks. Perubahan dilakukan dengan memberikan nilai baru pada posisi yang ditentukan.',
        'contoh': 'int angka[3] = {10, 20, 30};\nangka[1] = 50;',
      },
      {
        'bab_id': 5,
        'judul': '4. Array dan Perulangan',
        'isi': 'Perulangan dapat digunakan untuk membaca seluruh elemen array. Indeks dimulai dari 0 sampai kurang dari jumlah elemen.',
        'contoh': 'int angka[3] = {10, 20, 30};\nfor (int i = 0; i < 3; i++) {\n  cout << angka[i] << endl;\n}',
      },
      {
        'bab_id': 5,
        'judul': '5. Array Dua Dimensi',
        'isi': 'Array dua dimensi menyimpan data dalam bentuk baris dan kolom, seperti tabel. Setiap elemen diakses menggunakan indeks baris dan kolom.',
        'contoh': 'int nilai[2][2] = {{80, 90}, {75, 85}};\ncout << nilai[0][1]; // 90',
      },
    ];

    for (final item in materi) {
      await db.insert('materi', item);
    }

    const flashcards = [
      // BAB 1: VARIABEL
      {
        'bab_id': 1,
        'pertanyaan': 'Apa yang dimaksud dengan variabel?',
        'jawaban': 'Tempat untuk menyimpan data atau nilai yang memiliki nama dan tipe data.',
        'contoh': 'int umur = 20;',
      },
      {
        'bab_id': 1,
        'pertanyaan': 'Apa perbedaan deklarasi dan inisialisasi?',
        'jawaban': 'Deklarasi mengenalkan variabel. Inisialisasi memberikan nilai awal kepada variabel.',
        'contoh': 'int umur; // deklarasi\numur = 20; // pemberian nilai',
      },
      {
        'bab_id': 1,
        'pertanyaan': 'Bagaimana cara mengubah nilai variabel?',
        'jawaban': 'Berikan nilai baru menggunakan operator penugasan = selama tipe datanya sesuai.',
        'contoh': 'int nilai = 80;\nnilai = 90;',
      },
      {
        'bab_id': 1,
        'pertanyaan': 'Apakah nama variabel boleh diawali angka?',
        'jawaban': 'Tidak. Nama variabel tidak boleh diawali angka dan tidak boleh menggunakan kata kunci C++.',
        'contoh': 'int nilai1 = 80; // benar',
      },
      {
        'bab_id': 1,
        'pertanyaan': 'Apa fungsi const?',
        'jawaban': 'Membuat variabel yang nilainya tidak dapat diubah setelah diinisialisasi.',
        'contoh': 'const double phi = 3.14159;',
      },

      // BAB 2: TIPE DATA
      {
        'bab_id': 2,
        'pertanyaan': 'Apa fungsi tipe data?',
        'jawaban': 'Menentukan jenis nilai yang dapat disimpan dan diolah oleh variabel.',
        'contoh': 'int umur = 20;',
      },
      {
        'bab_id': 2,
        'pertanyaan': 'Untuk apa tipe int digunakan?',
        'jawaban': 'Untuk menyimpan bilangan bulat, seperti jumlah siswa atau umur dalam tahun.',
        'contoh': 'int jumlahSiswa = 32;',
      },
      {
        'bab_id': 2,
        'pertanyaan': 'Apa perbedaan float dan double?',
        'jawaban': 'Keduanya menyimpan bilangan pecahan, tetapi double umumnya memiliki presisi lebih tinggi.',
        'contoh': 'float berat = 52.5f;\ndouble nilai = 87.75;',
      },
      {
        'bab_id': 2,
        'pertanyaan': 'Apa perbedaan char dan string?',
        'jawaban': 'Char menyimpan satu karakter, sedangkan string menyimpan rangkaian karakter.',
        'contoh': 'char kelas = \'A\';\nstring nama = "Budi";',
      },
      {
        'bab_id': 2,
        'pertanyaan': 'Nilai apa yang disimpan oleh bool?',
        'jawaban': 'Nilai logika true atau false.',
        'contoh': 'bool lulus = true;',
      },

      // BAB 3: PERCABANGAN
      {
        'bab_id': 3,
        'pertanyaan': 'Apa fungsi percabangan?',
        'jawaban':
            'Memilih tindakan yang dijalankan berdasarkan kondisi tertentu.',
        'contoh': 'if (nilai >= 75) {\n  cout << "Lulus";\n}',
      },
      {
        'bab_id': 3,
        'pertanyaan': 'Kapan blok if dijalankan?',
        'jawaban': 'Ketika kondisi yang diperiksa bernilai benar atau true.',
        'contoh': 'if (umur >= 17) {\n  cout << "Dewasa";\n}',
      },
      {
        'bab_id': 3,
        'pertanyaan': 'Apa fungsi else pada if-else?',
        'jawaban': 'Menjalankan pilihan alternatif ketika kondisi pada if bernilai salah.',
        'contoh': 'if (nilai >= 75) {\n  cout << "Lulus";\n} else {\n  cout << "Remedial";\n}',
      },
      {
        'bab_id': 3,
        'pertanyaan': 'Untuk apa else-if digunakan?',
        'jawaban': 'Memeriksa beberapa kondisi secara berurutan dan memilih blok yang kondisinya benar pertama kali.',
        'contoh': 'if (nilai >= 90) {\n  cout << "A";\n} else if (nilai >= 80) {\n  cout << "B";\n}',
      },
      {
        'bab_id': 3,
        'pertanyaan': 'Apa arti operator && dan ||?',
        'jawaban': '&& berarti dan; || berarti atau. Keduanya digunakan untuk menggabungkan kondisi.',
        'contoh': 'if (nilai >= 75 && hadir >= 80) {\n  cout << "Lulus";\n}',
      },

      // BAB 4: PERULANGAN
      {
        'bab_id': 4,
        'pertanyaan': 'Apa fungsi perulangan?',
        'jawaban': 'Menjalankan suatu blok kode berulang kali selama kondisi atau aturan perulangan terpenuhi.',
        'contoh': 'for (int i = 0; i < 5; i++) {\n  cout << i;\n}',
      },
      {
        'bab_id': 4,
        'pertanyaan': 'Kapan perulangan for cocok digunakan?',
        'jawaban': 'Ketika jumlah pengulangan diketahui atau dapat ditentukan dengan penghitung.',
        'contoh': 'for (int i = 1; i <= 5; i++) {\n  cout << i;\n}',
      },
      {
        'bab_id': 4,
        'pertanyaan': 'Kapan kondisi while diperiksa?',
        'jawaban': 'Sebelum blok kode dijalankan. Jika kondisi awal salah, blok tidak dijalankan.',
        'contoh': 'int i = 1;\nwhile (i <= 5) {\n  cout << i;\n  i++;\n}',
      },
      {
        'bab_id': 4,
        'pertanyaan': 'Apa keistimewaan do-while?',
        'jawaban': 'Blok kode dijalankan terlebih dahulu, sehingga selalu berlangsung minimal satu kali.',
        'contoh': 'int i = 1;\ndo {\n  cout << i;\n  i++;\n} while (i <= 5);',
      },
      {
        'bab_id': 4,
        'pertanyaan': 'Apa perbedaan break dan continue?',
        'jawaban': 'Break menghentikan perulangan; continue melewati sisa perintah pada putaran saat ini.',
        'contoh': 'if (i == 3) continue;',
      },

      // BAB 5: STRUKTUR DATA
      {
        'bab_id': 5,
        'pertanyaan': 'Apa yang dimaksud dengan array?',
        'jawaban': 'Struktur data yang menyimpan sejumlah elemen bertipe sama dengan satu nama variabel.',
        'contoh': 'int angka[3] = {10, 20, 30};',
      },
      {
        'bab_id': 5,
        'pertanyaan': 'Dari angka berapa indeks array C++ dimulai?',
        'jawaban': 'Indeks array dimulai dari 0.',
        'contoh': 'int angka[3] = {10, 20, 30};\ncout << angka[0];',
      },
      {
        'bab_id': 5,
        'pertanyaan': 'Bagaimana mengubah elemen array?',
        'jawaban': 'Gunakan nama array, indeks elemen, dan operator penugasan.',
        'contoh': 'angka[1] = 50;',
      },
      {
        'bab_id': 5,
        'pertanyaan': 'Bagaimana cara membaca semua elemen array?',
        'jawaban': 'Gunakan perulangan dan indeks dari 0 sampai kurang dari jumlah elemen.',
        'contoh': 'for (int i = 0; i < 3; i++) {\n  cout << angka[i];\n}',
      },
      {
        'bab_id': 5,
        'pertanyaan': 'Apa itu array dua dimensi?',
        'jawaban': 'Array yang menyimpan data dalam baris dan kolom dan diakses dengan dua indeks.',
        'contoh': 'int nilai[2][2] = {{80, 90}, {75, 85}};',
      },
    ];

    for (final item in flashcards) {
      await db.insert('flashcard', item);
    }

    const latihan = [
      {
        'bab_id': 1,
        'instruksi': 'Buat variabel integer bernama umur dengan nilai 20.',
        'contoh': 'int umur = 20;',
        'template': 'int umur = 20;',
        'kunci': 'int umur = 20;',
        'output': 'Variabel umur berhasil dibuat.',
      },
      {
        'bab_id': 2,
        'instruksi': 'Buat variabel double bernama nilai dengan nilai 90.5.',
        'contoh': 'double nilai = 90.5;',
        'template': 'double nilai = 90.5;',
        'kunci': 'double nilai = 90.5;',
        'output': 'Variabel nilai berhasil dibuat.',
      },
      {
        'bab_id': 3,
        'instruksi': 'Buat IF yang menampilkan Lulus jika nilai >= 75.',
        'contoh': 'if (nilai >= 75) {\n  cout << "Lulus";\n}',
        'template': 'if (nilai >= 75) {\n  cout << "Lulus";\n}',
        'kunci': 'if (nilai >= 75) {\n  cout << "Lulus";\n}',
        'output': 'Percabangan berhasil.',
      },
      {
        'bab_id': 4,
        'instruksi': 'Buat FOR untuk mencetak angka 0 sampai 4.',
        'contoh': 'for (int i = 0; i < 5; i++) {\n  cout << i;\n}',
        'template': 'for (int i = 0; i < 5; i++) {\n  cout << i;\n}',
        'kunci': 'for (int i = 0; i < 5; i++) {\n  cout << i;\n}',
        'output': 'Perulangan berhasil.',
      },
      {
        'bab_id': 5,
        'instruksi': 'Buat array integer berisi 10, 20, 30.',
        'contoh': 'int angka[3] = {10, 20, 30};',
        'template': 'int angka[3] = {10, 20, 30};',
        'kunci': 'int angka[3] = {10, 20, 30};',
        'output': 'Array berhasil dibuat.',
      },
    ];

    for (final item in latihan) {
      await db.insert('latihan_kode', item);
    }
  }

  Database get database {
    if (_database == null) {
      throw StateError('Database belum diinisialisasi.');
    }

    return _database!;
  }

  // Membuat salt acak untuk setiap akun.
  String _buatSalt() {
    final random = Random.secure();

    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  Future<int> daftarAkun({
    required String nama,
    required String username,
    required String password,
  }) async {
    final namaBersih = nama.trim();
    final usernameBersih = username.trim().toLowerCase();

    if (namaBersih.isEmpty || usernameBersih.isEmpty || password.isEmpty) {
      throw ArgumentError('Nama, nama pengguna, dan kata sandi wajib diisi.');
    }

    final db = database;
    final salt = _buatSalt();

    final id = await db.transaction<int>((txn) async {
      final akunLama = await txn.query(
        'pengguna',
        columns: ['id'],
        where: 'LOWER(username) = ?',
        whereArgs: [usernameBersih],
        limit: 1,
      );

      if (akunLama.isNotEmpty) {
        throw Exception('Nama pengguna sudah digunakan.');
      }

      final penggunaId = await txn.insert('pengguna', {
        'nama': namaBersih,
        'username': usernameBersih,
        'salt': salt,
        'password_hash': _hashPassword(password, salt),
      });

      await txn.insert('sesi_login', {
        'id': 1,
        'pengguna_id': penggunaId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return penggunaId;
    });

    userId = id;
    return id;
  }

  Future<Map<String, Object?>?> loginAkun({
    required String username,
    required String password,
  }) async {
    final db = database;

    final hasil = await db.query(
      'pengguna',
      where: 'LOWER(username) = ?',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );

    if (hasil.isEmpty) return null;

    final akun = hasil.first;
    final salt = akun['salt'] as String?;
    final passwordHash = akun['password_hash'] as String?;

    if (salt == null ||
        passwordHash == null ||
        _hashPassword(password, salt) != passwordHash) {
      return null;
    }

    final id = akun['id'] as int;
    await db.insert('sesi_login', {
      'id': 1,
      'pengguna_id': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    userId = id;
    return akun;
  }

  Future<Map<String, Object?>?> cekSesiLogin() async {
    final hasil = await database.rawQuery('''
      SELECT pengguna.id, pengguna.nama
      FROM sesi_login
      JOIN pengguna ON pengguna.id = sesi_login.pengguna_id
      WHERE sesi_login.id = 1
      LIMIT 1
    ''');

    if (hasil.isEmpty) return null;

    userId = hasil.first['id'] as int;
    return hasil.first;
  }

  Future<Map<String, Object?>?> getPenggunaAktif() async {
    if (userId == 0) return null;

    final hasil = await database.query(
      'pengguna',
      columns: ['id', 'nama', 'username'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (hasil.isEmpty) return null;
    return hasil.first;
  }

  Future<void> updateNamaPengguna({required String nama}) async {
    final namaBersih = nama.trim();

    if (userId == 0) {
      throw StateError('Tidak ada pengguna yang sedang login.');
    }

    if (namaBersih.isEmpty) {
      throw ArgumentError('Nama tidak boleh kosong.');
    }

    await database.update(
      'pengguna',
      {'nama': namaBersih},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> logout() async {
    await database.delete('sesi_login', where: 'id = ?', whereArgs: [1]);

    userId = 0;
  }

  Future<void> simpanFlashcardStatus({
    required int flashcardId,
    required String status,
  }) async {
    await database.insert('log_belajar', {
      'pengguna_id': userId,
      'flashcard_id': flashcardId,
      'status': status,
      'tanggal': DateTime.now().toIso8601String(),
    });
    progressDataVersion.value++;
  }

  Future<void> simpanHasilLatihan({
    required int latihanId,
    required String kode,
    required bool benar,
    required String keterangan,
  }) async {
    await database.insert('hasil_latihan', {
      'pengguna_id': userId,
      'latihan_id': latihanId,
      'kode': kode,
      'status': benar ? 'Benar' : 'Belum Benar',
      'keterangan': keterangan,
      'tanggal': DateTime.now().toIso8601String(),
    });
    progressDataVersion.value++;
  }
}

// ============================================================
// APP
// ============================================================

enum TextSizeOption { small, medium, large }

class AppSettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  TextSizeOption textSize = TextSizeOption.medium;

  double get textScale => switch (textSize) {
    TextSizeOption.small => 0.9,
    TextSizeOption.medium => 1,
    TextSizeOption.large => 1.15,
  };

  Future<void> load() async {
    final preferences = await DatabaseHelper.instance.getAppPreferences();
    themeMode = switch (preferences['theme_mode']) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    textSize = switch (preferences['text_size']) {
      'small' => TextSizeOption.small,
      'large' => TextSizeOption.large,
      _ => TextSizeOption.medium,
    };
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    await DatabaseHelper.instance.saveAppPreference(
      key: 'theme_mode',
      value: value == ThemeMode.dark ? 'dark' : 'light',
    );
    themeMode = value;
    notifyListeners();
  }

  Future<void> setTextSize(TextSizeOption value) async {
    await DatabaseHelper.instance.saveAppPreference(
      key: 'text_size',
      value: value.name,
    );
    textSize = value;
    notifyListeners();
  }
}

class LexiFlipApp extends StatelessWidget {
  final AppSettingsController settings;
  final Object? initializationError;

  const LexiFlipApp({
    super.key,
    required this.settings,
    this.initializationError,
  });

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xffF6F7FB)
          : colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LexiFlip',
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(settings.textScale)),
          child: child!,
        ),
        home: initializationError == null
            ? StartPage(settings: settings)
            : StartupErrorPage(settings: settings),
      ),
    );
  }
}

class StartupErrorPage extends StatefulWidget {
  final AppSettingsController settings;

  const StartupErrorPage({super.key, required this.settings});

  @override
  State<StartupErrorPage> createState() => _StartupErrorPageState();
}

class _StartupErrorPageState extends State<StartupErrorPage> {
  bool retrying = false;

  Future<void> retryInitialization() async {
    setState(() => retrying = true);

    try {
      await DatabaseHelper.instance.initDatabase();
      await widget.settings.load();

      if (!mounted) return;

      unawaited(
        Navigator.pushReplacement<void, void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => StartPage(settings: widget.settings),
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logDatabaseError(
        'Gagal mengulangi inisialisasi database atau pengaturan',
        error,
        stackTrace,
      );
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'LexiFlip belum dapat dimulai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Database atau pengaturan aplikasi gagal dimuat. '
                  'Periksa penyimpanan perangkat, lalu coba lagi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: retrying ? null : retryInitialization,
                  child: retrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final AppSettingsController settings;

  const SettingsPage({super.key, required this.settings});

  Future<void> _changeTheme(BuildContext context, ThemeMode mode) async {
    try {
      await settings.setThemeMode(mode);
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal menyimpan tema', error, stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gagal menyimpan tema.')));
    }
  }

  Future<void> _changeTextSize(
    BuildContext context,
    TextSizeOption size,
  ) async {
    try {
      await settings.setTextSize(size);
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal menyimpan ukuran teks', error, stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan ukuran teks.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Tampilan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Terang'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Gelap'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selection) {
                        _changeTheme(context, selection.first);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ukuran teks',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<TextSizeOption>(
                      segments: const [
                        ButtonSegment(
                          value: TextSizeOption.small,
                          label: Text('Kecil'),
                        ),
                        ButtonSegment(
                          value: TextSizeOption.medium,
                          label: Text('Sedang'),
                        ),
                        ButtonSegment(
                          value: TextSizeOption.large,
                          label: Text('Besar'),
                        ),
                      ],
                      selected: {settings.textSize},
                      onSelectionChanged: (selection) {
                        _changeTextSize(context, selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HALAMAN AWAL: DAFTAR ATAU LOGIN
// ============================================================

class StartPage extends StatefulWidget {
  final AppSettingsController settings;

  const StartPage({super.key, required this.settings});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  late final Future<Map<String, Object?>?> _loginSession =
      _withDatabaseErrorLogging(
        'Gagal membaca sesi login',
        DatabaseHelper.instance.cekSesiLogin,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>?>(
      future: _loginSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Sesi pengguna tidak dapat dimuat. '
                'Periksa penyimpanan aplikasi dan coba lagi.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final akun = snapshot.data;

        if (akun != null) {
          return DashboardPage(
            nama: akun['nama'] as String? ?? '',
            settings: widget.settings,
          );
        }

        return WelcomePage(settings: widget.settings);
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  final AppSettingsController? settings;

  const WelcomePage({super.key, this.settings});

  @override
  Widget build(BuildContext context) {
    final appSettings = settings ?? AppSettingsController();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Pengaturan',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(settings: appSettings),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
                Icon(
                  Icons.style_rounded,
                  size: 90,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'LexiFlip',
                  style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Belajar Dasar Pemrograman C++',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 35),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DaftarAkunPage(settings: appSettings),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('DAFTAR AKUN'),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginPage(settings: appSettings),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('LOGIN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HALAMAN DAFTAR AKUN
// ============================================================

class DaftarAkunPage extends StatefulWidget {
  final AppSettingsController settings;

  const DaftarAkunPage({super.key, required this.settings});

  @override
  State<DaftarAkunPage> createState() => _DaftarAkunPageState();
}

class _DaftarAkunPageState extends State<DaftarAkunPage> {
  final namaController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final konfirmasiController = TextEditingController();

  bool loading = false;
  bool sembunyikanPassword = true;

  @override
  void dispose() {
    namaController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    konfirmasiController.dispose();
    super.dispose();
  }

  Future<void> daftar() async {
    final nama = namaController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final konfirmasi = konfirmasiController.text;

    if (nama.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Semua kolom wajib diisi.')));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi minimal 6 karakter.')),
      );
      return;
    }

    if (password != konfirmasi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi kata sandi tidak sama.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await DatabaseHelper.instance.daftarAkun(
        nama: nama,
        username: username,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(nama: nama, settings: widget.settings),
        ),
        (route) => false,
      );
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal membuat akun', error, stackTrace);
      if (!mounted) return;

      final message =
          error.toString().contains('Nama pengguna sudah digunakan.')
          ? 'Nama pengguna sudah digunakan.'
          : 'Akun tidak dapat dibuat. Coba lagi.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Buat akun LexiFlip',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: namaController,
            decoration: const InputDecoration(
              labelText: 'Nama lengkap',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: usernameController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Nama pengguna',
              prefixIcon: Icon(Icons.account_circle),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: sembunyikanPassword,
            decoration: InputDecoration(
              labelText: 'Kata sandi',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => sembunyikanPassword = !sembunyikanPassword),
                icon: Icon(
                  sembunyikanPassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: konfirmasiController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Konfirmasi kata sandi',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : daftar,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('BUAT AKUN'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HALAMAN LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  final AppSettingsController settings;

  const LoginPage({super.key, required this.settings});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama pengguna dan kata sandi.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final akun = await DatabaseHelper.instance.loginAkun(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (akun == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama pengguna atau kata sandi salah.')),
        );
        return;
      }

      final nama = akun['nama'] as String? ?? '';

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(nama: nama, settings: widget.settings),
        ),
        (route) => false,
      );
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal login', error, stackTrace);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login tidak dapat diproses.')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login LexiFlip')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Selamat datang kembali!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: usernameController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Nama pengguna',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Kata sandi',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('LOGIN'),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatefulWidget {
  final String nama;
  final AppSettingsController settings;

  const DashboardPage({super.key, required this.nama, required this.settings});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int halaman = 0;
  late String nama;

  @override
  void initState() {
    super.initState();
    nama = widget.nama;
  }

  Future<void> keluar() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text(
          'Apakah kamu yakin ingin keluar dan kembali ke halaman masuk?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    // Hapus sesi, tetapi akun dan progres tidak dihapus.
    try {
      await DatabaseHelper.instance.logout();
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal keluar dari akun', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal keluar dari akun.')));
      return;
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => StartPage(settings: widget.settings)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardHome(
        nama: nama,
        onOpen: (index) {
          setState(() {
            halaman = index;
          });
        },
        onOpenProfile: () async {
          final hasil = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );

          if (hasil is String && hasil.trim().isNotEmpty) {
            setState(() {
              nama = hasil.trim();
            });
          }
        },
      ),
      const ChapterPage(mode: 'materi'),
      const ChapterPage(mode: 'flashcard'),
      const ChapterPage(mode: 'latihan'),
      const ProgressPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LexiFlip',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(settings: widget.settings),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Profil',
            onPressed: () async {
              final hasil = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );

              if (hasil is String && hasil.trim().isNotEmpty) {
                setState(() {
                  nama = hasil.trim();
                });
              }
            },
            icon: const Icon(Icons.person),
          ),
          IconButton(
            tooltip: 'Statistik',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProgressPage(statistikSaja: true),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: keluar,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(index: halaman, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: halaman,
        onDestinationSelected: (index) {
          setState(() {
            halaman = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Materi',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Flashcard',
          ),
          NavigationDestination(
            icon: Icon(Icons.code_outlined),
            selectedIcon: Icon(Icons.code),
            label: 'Latihan',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD HOME
// ============================================================

class DashboardHome extends StatelessWidget {
  final String nama;
  final ValueChanged<int> onOpen;
  final VoidCallback onOpenProfile;

  const DashboardHome({
    super.key,
    required this.nama,
    required this.onOpen,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Halo, $nama! 👋',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        const Text('Selamat belajar C++ hari ini!'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onOpenProfile,
            icon: const Icon(Icons.person_outline),
            label: const Text('Profil Saya'),
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'Daftar Bab',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _withDatabaseErrorLogging(
            'Gagal memuat bab di dashboard',
            () => DatabaseHelper.instance.database.query(
              'bab',
              orderBy: 'urutan ASC',
            ),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _MessageCard(
                message:
                    'Bab tidak dapat dimuat. Coba buka kembali halaman ini.',
              );
            }

            final data = snapshot.data ?? [];

            if (data.isEmpty) {
              return const _MessageCard(message: 'Belum ada data bab.');
            }

            return Column(
              children: data.map((bab) {
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${bab['urutan']}')),
                    title: Text('${bab['judul']}'),
                    subtitle: Text('${bab['deskripsi']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChapterDetailPage(bab: bab),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 15),
        const Text(
          'Menu Belajar',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _menuButton('Materi', Icons.menu_book, 1),
            _menuButton('Flashcard', Icons.style, 2),
            _menuButton('Latihan', Icons.code, 3),
            _menuButton('Progress', Icons.insights, 4),
          ],
        ),
      ],
    );
  }

  Widget _menuButton(String title, IconData icon, int index) {
    return SizedBox(
      width: 155,
      child: OutlinedButton.icon(
        onPressed: () => onOpen(index),
        icon: Icon(icon),
        label: Text(title),
      ),
    );
  }
}

// ============================================================
// CHAPTER PAGE
// ============================================================

class ChapterPage extends StatelessWidget {
  final String mode;

  const ChapterPage({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    String title;

    if (mode == 'materi') {
      title = 'Pilih Bab Materi';
    } else if (mode == 'flashcard') {
      title = 'Pilih Bab Flashcard';
    } else {
      title = 'Pilih Bab Latihan';
    }

    return FutureBuilder<List<Map<String, Object?>>>(
      future: _withDatabaseErrorLogging(
        'Gagal memuat daftar bab',
        () => DatabaseHelper.instance.database.query(
          'bab',
          orderBy: 'urutan ASC',
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Daftar bab tidak dapat dimuat. Coba buka kembali halaman ini.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return const Center(child: Text('Belum ada data bab.'));
        }

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            ...data.map((bab) {
              return Card(
                child: ListTile(
                  title: Text('${bab['urutan']}. ${bab['judul']}'),
                  subtitle: Text('${bab['deskripsi']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Widget page;

                    if (mode == 'materi') {
                      page = MateriPage(bab: bab);
                    } else if (mode == 'flashcard') {
                      page = FlashcardPage(bab: bab);
                    } else {
                      page = LatihanPage(bab: bab);
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => page),
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ============================================================
// DETAIL BAB
// ============================================================

class ChapterDetailPage extends StatelessWidget {
  final Map<String, Object?> bab;

  const ChapterDetailPage({super.key, required this.bab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${bab['judul']}')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('${bab['deskripsi']}', style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 25),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MateriPage(bab: bab)),
              );
            },
            icon: const Icon(Icons.menu_book),
            label: const Text('Belajar Materi'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FlashcardPage(bab: bab)),
              );
            },
            icon: const Icon(Icons.style),
            label: const Text('Mulai Flashcard'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LatihanPage(bab: bab)),
              );
            },
            icon: const Icon(Icons.code),
            label: const Text('Kerjakan Latihan'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MATERI
// ============================================================

class MateriPage extends StatefulWidget {
  final Map<String, Object?> bab;

  const MateriPage({super.key, required this.bab});

  @override
  State<MateriPage> createState() => _MateriPageState();
}

class _MateriPageState extends State<MateriPage> {
  late final Future<_MateriPageData> _futureMateri = _withDatabaseErrorLogging(
    'Gagal memuat materi',
    _muatMateri,
  );
  final Set<int> _baruDitandaiSelesai = {};

  Future<_MateriPageData> _muatMateri() async {
    final data = await DatabaseHelper.instance.database.query(
      'materi',
      where: 'bab_id = ?',
      whereArgs: [widget.bab['id']],
    );
    final ids = data.map((materi) => materi['id']).whereType<int>().toList();
    final selesaiIds = await DatabaseHelper.instance.getMateriSelesaiIds(
      materiIds: ids,
    );
    return _MateriPageData(materi: data, selesaiIds: selesaiIds);
  }

  Future<void> _tandaiSelesai(int materiId) async {
    try {
      await DatabaseHelper.instance.tandaiMateriSelesai(materiId: materiId);
      if (!mounted) return;
      setState(() => _baruDitandaiSelesai.add(materiId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Materi ditandai selesai.')));
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal menyimpan progres materi', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan progres materi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.bab['judul']}')),
      body: FutureBuilder<_MateriPageData>(
        future: _futureMateri,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Materi tidak dapat dimuat. Coba buka kembali halaman ini.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final data = snapshot.data?.materi ?? [];
          final selesaiIds = <int>{
            ...?snapshot.data?.selesaiIds,
            ..._baruDitandaiSelesai,
          };

          if (data.isEmpty) {
            return const Center(child: Text('Belum ada materi pada bab ini.'));
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: data.map((materi) {
              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${materi['judul']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${materi['isi']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Contoh Kode:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      CodeBox(text: '${materi['contoh']}'),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed:
                              materi['id'] is int &&
                                  !selesaiIds.contains(materi['id'])
                              ? () => _tandaiSelesai(materi['id'] as int)
                              : null,
                          icon: Icon(
                            selesaiIds.contains(materi['id'])
                                ? Icons.check_circle
                                : Icons.check,
                          ),
                          label: Text(
                            selesaiIds.contains(materi['id'])
                                ? 'Selesai'
                                : 'Tandai selesai',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _MateriPageData {
  final List<Map<String, Object?>> materi;
  final Set<int> selesaiIds;

  const _MateriPageData({required this.materi, required this.selesaiIds});
}

// ============================================================
// CODE BOX
// ============================================================

class CodeBox extends StatelessWidget {
  final String text;

  const CodeBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text,
          style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FLASHCARD
// ============================================================

class FlashcardPage extends StatefulWidget {
  final Map<String, Object?> bab;

  const FlashcardPage({super.key, required this.bab});

  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  List<Map<String, Object?>> cards = [];

  int index = 0;
  bool dibalik = false;
  bool loading = true;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    try {
      final result = await DatabaseHelper.instance.database.query(
        'flashcard',
        where: 'bab_id = ?',
        whereArgs: [widget.bab['id']],
      );

      if (!mounted) return;

      setState(() {
        cards = result;
        loading = false;
      });
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal memuat flashcard', error, stackTrace);
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Flashcard tidak dapat dimuat. Coba buka kembali halaman ini.';
      });
    }
  }

  Future<void> simpanStatus(String status) async {
    if (cards.isEmpty) return;

    final flashcardId = cards[index]['id'];

    if (flashcardId is! int) return;

    try {
      await DatabaseHelper.instance.simpanFlashcardStatus(
        flashcardId: flashcardId,
        status: status,
      );
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal menyimpan status flashcard', error, stackTrace);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan status flashcard.')),
      );
      return;
    }

    if (!mounted) return;

    if (index < cards.length - 1) {
      setState(() {
        index++;
        dibalik = false;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardSelesaiPage(
            judulBab: '${widget.bab['judul']}',
            totalKartu: cards.length,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcard')),
        body: const Center(child: Text('Belum ada flashcard pada bab ini.')),
      );
    }

    final card = cards[index];

    return Scaffold(
      appBar: AppBar(title: Text('Flashcard ${index + 1}/${cards.length}')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    dibalik = !dibalik;
                  });
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey('$index-$dibalik'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: dibalik
                          ? colorScheme.secondaryContainer
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(blurRadius: 12, color: Color(0x22000000)),
                      ],
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              dibalik ? Icons.lightbulb : Icons.help_outline,
                              size: 55,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              dibalik
                                  ? '${card['jawaban']}'
                                  : '${card['pertanyaan']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (dibalik) ...[
                              const SizedBox(height: 20),
                              CodeBox(text: '${card['contoh']}'),
                            ],
                            const SizedBox(height: 20),
                            Text(
                              dibalik
                                  ? 'Ketuk untuk kembali'
                                  : 'Ketuk kartu untuk FLIP',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (dibalik) ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => simpanStatus('Belum Paham'),
                      icon: const Icon(Icons.close),
                      label: const Text('Belum Paham'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => simpanStatus('Paham'),
                      icon: const Icon(Icons.check),
                      label: const Text('Paham'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FlashcardSelesaiPage extends StatelessWidget {
  final String judulBab;
  final int totalKartu;

  const FlashcardSelesaiPage({
    super.key,
    required this.judulBab,
    required this.totalKartu,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belajar Selesai')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 90,
                color: Colors.amber,
              ),
              const SizedBox(height: 20),
              const Text(
                'Hebat! 🎉',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Kamu telah menyelesaikan flashcard '
                'bab $judulBab.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 10),
              Text('Total kartu: $totalKartu'),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali ke Daftar Bab'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LATIHAN KODE
// ============================================================

class LatihanPage extends StatefulWidget {
  final Map<String, Object?> bab;

  const LatihanPage({super.key, required this.bab});

  @override
  State<LatihanPage> createState() => _LatihanPageState();
}

class _LatihanPageState extends State<LatihanPage> {
  List<Map<String, Object?>> latihan = [];

  int index = 0;
  bool loading = true;

  String? errorMessage;
  String hasil = '';

  final TextEditingController codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadLatihan();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> loadLatihan() async {
    try {
      final result = await DatabaseHelper.instance.database.query(
        'latihan_kode',
        where: 'bab_id = ?',
        whereArgs: [widget.bab['id']],
      );

      if (!mounted) return;

      setState(() {
        latihan = result;
        loading = false;
      });
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal memuat latihan', error, stackTrace);
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Latihan tidak dapat dimuat. Coba buka kembali halaman ini.';
      });
    }
  }

  Future<void> runCode() async {
    if (latihan.isEmpty) return;

    final soal = latihan[index];

    final kode = codeController.text;
    if (kode.trim().isEmpty) {
      setState(() {
        hasil = 'Editor masih kosong. Tulis kode terlebih dahulu sebelum menekan Run.';
      });
      return;
    }

    final evaluation = evaluateCppAnswer(kode, '${soal['kunci']}');
    final benar = evaluation.isCorrect;

    final pesan = benar
        ? 'BENAR\n\n${evaluation.feedback}\n\n'
              'Hasil panduan: ${soal['output']}\n\n'
              'Kode diperiksa berdasarkan kunci latihan, bukan dijalankan.'
        : 'BELUM BENAR\n\nPetunjuk: ${evaluation.feedback}';

    try {
      await DatabaseHelper.instance.simpanHasilLatihan(
        latihanId: soal['id'] as int,
        kode: kode,
        benar: benar,
        keterangan: pesan,
      );
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal menyimpan hasil latihan', error, stackTrace);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan hasil latihan.')),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      hasil = pesan;
    });
  }

  void resetEditor() {
    setState(() {
      codeController.clear();
      hasil = '';
    });
  }

  void latihanBerikutnya() {
    if (index >= latihan.length - 1) return;

    setState(() {
      index++;
      codeController.clear();
      hasil = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Latihan')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (latihan.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Latihan')),
        body: const Center(child: Text('Belum ada latihan pada bab ini.')),
      );
    }

    final soal = latihan[index];

    return Scaffold(
      appBar: AppBar(title: Text('Latihan ${index + 1}/${latihan.length}')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '${soal['instruksi']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          const Text(
            'Contoh Kode:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          CodeBox(text: '${soal['contoh']}'),
          const SizedBox(height: 15),
          TextField(
            controller: codeController,
            maxLines: 8,
            inputFormatters: [CodeAutoIndentFormatter()],
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'Code Editor',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: runCode,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: resetEditor,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Output', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasil.isEmpty
                  ? colorScheme.surfaceContainerLow
                  : hasil.startsWith('BENAR\n')
                  ? colorScheme.secondaryContainer
                  : colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasil.isEmpty ? 'Hasil pemeriksaan akan tampil di sini.' : hasil,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasil.startsWith('BELUM BENAR')
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSurface,
              ),
            ),
          ),
          if (index < latihan.length - 1) ...[
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: latihanBerikutnya,
              child: const Text('Latihan Berikutnya'),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// PROFIL PENGGUNA
// ============================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController namaController = TextEditingController();
  bool loading = true;
  bool sedangMenyimpan = false;
  bool modeEdit = false;
  String? username;
  String? namaSaatIni;

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  @override
  void dispose() {
    namaController.dispose();
    super.dispose();
  }

  Future<void> _muatProfil() async {
    try {
      final data = await DatabaseHelper.instance.getPenggunaAktif();
      if (!mounted) return;

      final nama = data?['nama'] as String? ?? '';
      final user = data?['username'] as String? ?? '-';

      setState(() {
        loading = false;
        username = user;
        namaSaatIni = nama;
        namaController.text = nama;
      });
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal memuat profil', error, stackTrace);
      if (!mounted) return;

      setState(() {
        loading = false;
        username = '-';
        namaSaatIni = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil tidak dapat dimuat.')),
      );
    }
  }

  Future<void> _simpanProfil() async {
    final namaBaru = namaController.text.trim();

    if (namaBaru.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tampilan tidak boleh kosong.')),
      );
      return;
    }

    setState(() => sedangMenyimpan = true);

    try {
      await DatabaseHelper.instance.updateNamaPengguna(nama: namaBaru);

      if (!mounted) return;

      final namaTersimpan = namaBaru;
      setState(() {
        namaSaatIni = namaTersimpan;
        modeEdit = false;
      });

      Navigator.pop(context, namaTersimpan);
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal menyimpan profil', error, stackTrace);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil tidak dapat disimpan.')),
      );
    } finally {
      if (mounted) {
        setState(() => sedangMenyimpan = false);
      }
    }
  }

  void _batalEdit() {
    setState(() {
      modeEdit = false;
      namaController.text = namaSaatIni ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text(
            'Profil Pengguna',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama tampilan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (modeEdit)
                    TextField(
                      controller: namaController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Masukkan nama tampilan',
                      ),
                    )
                  else
                    Text(
                      namaSaatIni?.isNotEmpty == true
                          ? namaSaatIni!
                          : 'Belum ada nama',
                      style: const TextStyle(fontSize: 20),
                    ),
                  const SizedBox(height: 22),
                  const Text(
                    'Username',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(username ?? '-', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Password tidak ditampilkan untuk keamanan.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!modeEdit)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => setState(() => modeEdit = true),
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: sedangMenyimpan ? null : _simpanProfil,
                    icon: const Icon(Icons.save),
                    label: Text(sedangMenyimpan ? 'Menyimpan...' : 'Simpan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sedangMenyimpan ? null : _batalEdit,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// PROGRESS & STATISTIK
// ============================================================

class ProgressPage extends StatefulWidget {
  final bool statistikSaja;

  const ProgressPage({super.key, this.statistikSaja = false});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  // Future untuk statistik
  late Future<Map<String, Object?>> _futureStatistik;

  // Future untuk riwayat latihan
  late Future<List<Map<String, Object?>>> _futureHistory;

  @override
  void initState() {
    super.initState();

    // Pertama kali halaman dibuka
    _futureStatistik = _ambilStatistikDenganLog();
    _futureHistory = _ambilRiwayatDenganLog();
    progressDataVersion.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    progressDataVersion.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    refreshData(showMessage: false);
  }

  Future<Map<String, Object?>> _ambilStatistikDenganLog() =>
      _withDatabaseErrorLogging(
        'Gagal memuat statistik progres',
        ambilStatistik,
      );

  Future<List<Map<String, Object?>>> _ambilRiwayatDenganLog() =>
      _withDatabaseErrorLogging('Gagal memuat riwayat progres', ambilRiwayat);

  // ============================================================
  // AMBIL STATISTIK DARI DATABASE
  // ============================================================

  Future<Map<String, Object?>> ambilStatistik() async {
    final db = DatabaseHelper.instance.database;

    final totalMateri =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM materi'),
        ) ??
        0;

    final materiSelesai =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(DISTINCT materi_id)
            FROM log_materi
            INNER JOIN materi ON materi.id = log_materi.materi_id
            WHERE log_materi.pengguna_id = ?
            ''',
            [DatabaseHelper.userId],
          ),
        ) ??
        0;

    // ----------------------------------------------------------
    // TOTAL FLASHCARD
    // ----------------------------------------------------------

    final totalFlashcard =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM flashcard'),
        ) ??
        0;

    // ----------------------------------------------------------
    // FLASHCARD YANG SUDAH PAHAM
    // ----------------------------------------------------------

    final flashcardPaham =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(*)
            FROM log_belajar AS terbaru
            INNER JOIN (
              SELECT flashcard_id, MAX(id) AS log_id
              FROM log_belajar
              WHERE pengguna_id = ?
              GROUP BY flashcard_id
            ) AS terakhir
              ON terakhir.log_id = terbaru.id
            WHERE terbaru.status = ?
            ''',
            [DatabaseHelper.userId, 'Paham'],
          ),
        ) ??
        0;

    // ----------------------------------------------------------
    // TOTAL LATIHAN
    // ----------------------------------------------------------

    final totalLatihan =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM latihan_kode'),
        ) ??
        0;

    // ----------------------------------------------------------
    // LATIHAN YANG PERNAH DIKERJAKAN
    // ----------------------------------------------------------

    final latihanDikerjakan =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(DISTINCT latihan_id)
            FROM hasil_latihan
            INNER JOIN latihan_kode
              ON latihan_kode.id = hasil_latihan.latihan_id
            WHERE hasil_latihan.pengguna_id = ?
            ''',
            [DatabaseHelper.userId],
          ),
        ) ??
        0;

    final latihanBenar =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(DISTINCT latihan_id)
            FROM hasil_latihan
            INNER JOIN latihan_kode
              ON latihan_kode.id = hasil_latihan.latihan_id
            WHERE hasil_latihan.pengguna_id = ?
              AND hasil_latihan.status = ?
            ''',
            [DatabaseHelper.userId, 'Benar'],
          ),
        ) ??
        0;

    final latihanTerakhir = await db.query(
      'hasil_latihan',
      columns: ['status', 'tanggal'],
      where: 'pengguna_id = ?',
      whereArgs: [DatabaseHelper.userId],
      orderBy: 'id DESC',
      limit: 1,
    );

    return {
      'totalMateri': totalMateri,
      'materiSelesai': materiSelesai,
      'totalFlashcard': totalFlashcard,
      'flashcardPaham': flashcardPaham,
      'totalLatihan': totalLatihan,
      'latihanDikerjakan': latihanDikerjakan,
      'latihanBenar': latihanBenar,
      'nilaiLatihanTerakhir': latihanTerakhir.isEmpty
          ? null
          : latihanTerakhir.first['status'],
      'waktuLatihanTerakhir': latihanTerakhir.isEmpty
          ? null
          : latihanTerakhir.first['tanggal'],
    };
  }

  // ============================================================
  // AMBIL RIWAYAT LATIHAN
  // ============================================================

  Future<List<Map<String, Object?>>> ambilRiwayat() async {
    final db = DatabaseHelper.instance.database;

    return await db.rawQuery(
      '''
      SELECT
        hasil_latihan.*,
        latihan_kode.instruksi
      FROM hasil_latihan
      JOIN latihan_kode
        ON latihan_kode.id =
           hasil_latihan.latihan_id
      WHERE hasil_latihan.pengguna_id = ?
      ORDER BY hasil_latihan.tanggal DESC, hasil_latihan.id DESC
      LIMIT 10
      ''',
      [DatabaseHelper.userId],
    );
  }

  // ============================================================
  // FUNGSI REFRESH
  // ============================================================

  Future<void> refreshData({bool showMessage = true}) async {
    // Baca ulang data dari database
    final statistikBaru = _ambilStatistikDenganLog();
    final historyBaru = _ambilRiwayatDenganLog();

    // Masukkan Future baru ke halaman
    setState(() {
      _futureStatistik = statistikBaru;
      _futureHistory = historyBaru;
    });

    // Tunggu statistik selesai dibaca
    try {
      await _futureStatistik;
      await _futureHistory;
    } catch (error, stackTrace) {
      _logDatabaseError('Gagal memperbarui progress', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui progress.')),
      );
      return;
    }

    // Pastikan halaman masih aktif
    if (!mounted) return;

    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Progress berhasil diperbarui'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: widget.statistikSaja
          ? AppBar(
              title: const Text('Statistik'),

              // Tombol refresh di AppBar
              actions: [
                IconButton(
                  tooltip: 'Refresh Progress',
                  icon: const Icon(Icons.refresh),
                  onPressed: refreshData,
                ),
              ],
            )
          : null,

      // ========================================================
      // BODY
      // ========================================================
      body: FutureBuilder<Map<String, Object?>>(
        future: _futureStatistik,

        builder: (context, snapshot) {
          // ----------------------------------------------------
          // LOADING
          // ----------------------------------------------------

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // ----------------------------------------------------
          // ERROR
          // ----------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Statistik tidak dapat dimuat. Coba buka kembali halaman ini.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // ----------------------------------------------------
          // DATA
          // ----------------------------------------------------

          final data = snapshot.data ?? <String, Object?>{};
          final totalMateri = data['totalMateri'] as int? ?? 0;
          final materiSelesai = data['materiSelesai'] as int? ?? 0;
          final totalLatihan = data['totalLatihan'] as int? ?? 0;
          final latihanDikerjakan = data['latihanDikerjakan'] as int? ?? 0;
          final nilaiTerakhir = data['nilaiLatihanTerakhir'] as String?;
          final waktuTerakhir = data['waktuLatihanTerakhir'] as String?;
          final progress = totalMateri == 0
              ? 0.0
              : (materiSelesai / totalMateri).clamp(0.0, 1.0).toDouble();

          // ----------------------------------------------------
          // REFRESH INDICATOR
          // ----------------------------------------------------

          return RefreshIndicator(
            onRefresh: refreshData,

            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.all(18),

              children: [
                // ==================================================
                // JUDUL + TOMBOL REFRESH
                // ==================================================

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,

                  children: [
                    const Expanded(
                      child: Text(
                        'Progress Belajar',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // ----------------------------------------------
                    // TOMBOL REFRESH
                    // ----------------------------------------------
                    IconButton(
                      tooltip: 'Refresh Progress',

                      icon: const Icon(Icons.refresh, size: 30),

                      onPressed: refreshData,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==================================================
                // CARD PROGRESS
                // ==================================================
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Materi Selesai',

                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        // ------------------------------------------
                        // BAR PROGRESS
                        // ------------------------------------------
                        LinearProgressIndicator(value: progress, minHeight: 10),

                        const SizedBox(height: 10),

                        // ------------------------------------------
                        // PERSENTASE
                        // ------------------------------------------
                        Text('${(progress * 100).round()}% selesai'),

                        const SizedBox(height: 5),

                        // ------------------------------------------
                        // JUMLAH SELESAI
                        // ------------------------------------------
                        Text(
                          '$materiSelesai dari $totalMateri materi',

                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latihan',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$latihanDikerjakan dari $totalLatihan latihan pernah dikerjakan',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nilai latihan terakhir: '
                          '${nilaiTerakhir ?? 'Belum ada nilai'}',
                        ),
                        if (waktuTerakhir != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Waktu: ${formatTanggal(waktuTerakhir)}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // STATISTIK KARTU DAN LATIHAN
                // ==================================================
                Row(
                  children: [
                    // ----------------------------------------------
                    // KARTU PAHAM
                    // ----------------------------------------------

                    Expanded(
                      child: _statCard(
                        '${data['flashcardPaham'] ?? 0}',
                        'Kartu Paham',
                        Icons.style,
                      ),
                    ),

                    // ----------------------------------------------
                    // LATIHAN BENAR
                    // ----------------------------------------------
                    Expanded(
                      child: _statCard(
                        '${data['latihanBenar'] ?? 0}',
                        'Latihan Benar',
                        Icons.check_circle,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==================================================
                // RIWAYAT LATIHAN
                // ==================================================
                const Text(
                  'Riwayat Latihan',

                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // FUTURE BUILDER RIWAYAT
                // ==================================================
                FutureBuilder<List<Map<String, Object?>>>(
                  future: _futureHistory,

                  builder: (context, snapshot) {
                    // ------------------------------------------------
                    // LOADING
                    // ------------------------------------------------

                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // ------------------------------------------------
                    // ERROR
                    // ------------------------------------------------

                    if (snapshot.hasError) {
                      return _MessageCard(
                        message: 'Riwayat tidak dapat dimuat. Coba buka kembali halaman ini.',
                      );
                    }

                    // ------------------------------------------------
                    // DATA
                    // ------------------------------------------------

                    final history = snapshot.data ?? [];

                    // ------------------------------------------------
                    // BELUM ADA RIWAYAT
                    // ------------------------------------------------

                    if (history.isEmpty) {
                      return const _MessageCard(
                        message: 'Belum ada riwayat latihan.',
                      );
                    }

                    // ------------------------------------------------
                    // TAMPILKAN RIWAYAT
                    // ------------------------------------------------

                    return Column(
                      children: history.map((data) {
                        final benar = data['status'] == 'Benar';

                        return Card(
                          child: ListTile(
                            // ----------------------------------------
                            // ICON STATUS
                            // ----------------------------------------

                            leading: Icon(
                              benar ? Icons.check_circle : Icons.error,

                              color: benar
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.error,
                            ),

                            // ----------------------------------------
                            // STATUS
                            // ----------------------------------------
                            title: Text('${data['status']}'),

                            // ----------------------------------------
                            // INSTRUKSI
                            // ----------------------------------------
                            subtitle: Text(
                              '${data['instruksi']}\n'
                              '${formatTanggal(data['tanggal'])}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard(String angka, String judul, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [
            // ----------------------------------------------------
            // ICON
            // ----------------------------------------------------

            Icon(icon, size: 35, color: Theme.of(context).colorScheme.primary),

            const SizedBox(height: 5),

            // ----------------------------------------------------
            // ANGKA
            // ----------------------------------------------------
            Text(
              angka,

              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            // ----------------------------------------------------
            // JUDUL
            // ----------------------------------------------------
            Text(judul, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String formatTanggal(Object? value) {
    if (value is! String) return 'Waktu tidak tersedia';
    final tanggal = DateTime.tryParse(value)?.toLocal();
    if (tanggal == null) return value;

    String duaDigit(int angka) => angka.toString().padLeft(2, '0');

    return '${duaDigit(tanggal.day)}/${duaDigit(tanggal.month)}/'
        '${tanggal.year} ${duaDigit(tanggal.hour)}:${duaDigit(tanggal.minute)}';
  }
}

// ============================================================
// MESSAGE CARD
// ============================================================

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}

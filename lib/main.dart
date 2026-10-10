import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DatabaseHelper.instance.initDatabase();
  } catch (e) {
    debugPrint('Gagal menginisialisasi database: $e');
  }

  runApp(const LexiFlipApp());
}

// ============================================================
// DATABASE
// ============================================================

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static int userId = 0;
  static const String databaseName = 'lexiflip.db';

  Database? _database;

  Future<void> initDatabase() async {
    if (_database != null) return;

    final databasePath = p.join(await getDatabasesPath(), databaseName);

    _database = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDatabase(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _ensureAuthSchema(db);
        }
      },
    );
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
  }
}

// ============================================================
// APP
// ============================================================

class LexiFlipApp extends StatelessWidget {
  const LexiFlipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LexiFlip',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xffF6F7FB),
      ),
      home: const StartPage(),
    );
  }
}

// ============================================================
// HALAMAN AWAL: DAFTAR ATAU LOGIN
// ============================================================

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Object?>?>(
      future: DatabaseHelper.instance.cekSesiLogin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Gagal membuka database: ${snapshot.error}'),
            ),
          );
        }

        final akun = snapshot.data;

        if (akun != null) {
          return DashboardPage(nama: akun['nama'] as String? ?? '');
        }

        return const WelcomePage();
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.style_rounded, size: 90, color: Colors.indigo),
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
                          builder: (_) => const DaftarAkunPage(),
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
                        MaterialPageRoute(builder: (_) => const LoginPage()),
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
  const DaftarAkunPage({super.key});

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
        MaterialPageRoute(builder: (_) => DashboardPage(nama: nama)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
  const LoginPage({super.key});

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
        MaterialPageRoute(builder: (_) => DashboardPage(nama: nama)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login gagal: $e')));
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

  const DashboardPage({super.key, required this.nama});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int halaman = 0;

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
    await DatabaseHelper.instance.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StartPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardHome(
        nama: widget.nama,
        onOpen: (index) {
          setState(() {
            halaman = index;
          });
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

  const DashboardHome({super.key, required this.nama, required this.onOpen});

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
        const SizedBox(height: 25),
        const Text(
          'Daftar Bab',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, Object?>>>(
          future: DatabaseHelper.instance.database.query(
            'bab',
            orderBy: 'urutan ASC',
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
                message: 'Gagal memuat bab: ${snapshot.error}',
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
      future: DatabaseHelper.instance.database.query(
        'bab',
        orderBy: 'urutan ASC',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat bab:\n${snapshot.error}',
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

class MateriPage extends StatelessWidget {
  final Map<String, Object?> bab;

  const MateriPage({super.key, required this.bab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${bab['judul']}')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: DatabaseHelper.instance.database.query(
          'materi',
          where: 'bab_id = ?',
          whereArgs: [bab['id']],
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Gagal memuat materi:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final data = snapshot.data ?? [];

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

// ============================================================
// CODE BOX
// ============================================================

class CodeBox extends StatelessWidget {
  final String text;

  const CodeBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Gagal memuat flashcard: $e';
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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan status: $e')));
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
                      color: dibalik ? Colors.indigo.shade50 : Colors.white,
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
                              color: Colors.indigo,
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
                              style: const TextStyle(color: Colors.grey),
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

  final TextEditingController kodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadLatihan();
  }

  @override
  void dispose() {
    kodeController.dispose();
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

        if (result.isNotEmpty) {
          kodeController.text = '${result.first['template']}';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Gagal memuat latihan: $e';
      });
    }
  }

  String normalisasiKode(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> runCode() async {
    if (latihan.isEmpty) return;

    final soal = latihan[index];

    final input = normalisasiKode(kodeController.text);

    final jawaban = normalisasiKode('${soal['kunci']}');

    final benar = input == jawaban;

    final pesan = benar
        ? 'BENAR\n\n${soal['output']}'
        : 'BELUM BENAR\n\nPeriksa kembali kode yang kamu tulis.';

    try {
      await DatabaseHelper.instance.simpanHasilLatihan(
        latihanId: soal['id'] as int,
        kode: kodeController.text,
        benar: benar,
        keterangan: pesan,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan hasil latihan: $e')),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      hasil = pesan;
    });
  }

  void latihanBerikutnya() {
    if (index >= latihan.length - 1) return;

    setState(() {
      index++;
      kodeController.text = '${latihan[index]['template']}';
      hasil = '';
    });
  }

  @override
  Widget build(BuildContext context) {
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
            controller: kodeController,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'Code Editor',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: runCode,
              icon: const Icon(Icons.play_arrow),
              label: const Text('RUN'),
            ),
          ),
          if (hasil.isNotEmpty) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasil.startsWith('BENAR')
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasil,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
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
  late Future<Map<String, int>> _futureStatistik;

  // Future untuk riwayat latihan
  late Future<List<Map<String, Object?>>> _futureHistory;

  @override
  void initState() {
    super.initState();

    // Pertama kali halaman dibuka
    _futureStatistik = ambilStatistik();
    _futureHistory = ambilRiwayat();
  }

  // ============================================================
  // AMBIL STATISTIK DARI DATABASE
  // ============================================================

  Future<Map<String, int>> ambilStatistik() async {
    final db = DatabaseHelper.instance.database;

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
            SELECT COUNT(DISTINCT flashcard_id)
            FROM log_belajar
            WHERE pengguna_id = ?
              AND status = ?
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
    // LATIHAN YANG SUDAH BENAR
    // ----------------------------------------------------------

    final latihanBenar =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(DISTINCT latihan_id)
            FROM hasil_latihan
            WHERE pengguna_id = ?
              AND status = ?
            ''',
            [DatabaseHelper.userId, 'Benar'],
          ),
        ) ??
        0;

    // ----------------------------------------------------------
    // HITUNG TOTAL AKTIVITAS
    // ----------------------------------------------------------

    final totalAktivitas = totalFlashcard + totalLatihan;

    // ----------------------------------------------------------
    // HITUNG AKTIVITAS SELESAI
    // ----------------------------------------------------------

    final selesaiAktivitas = flashcardPaham + latihanBenar;

    // ----------------------------------------------------------
    // KEMBALIKAN DATA
    // ----------------------------------------------------------

    return {
      'totalFlashcard': totalFlashcard,
      'flashcardPaham': flashcardPaham,
      'totalLatihan': totalLatihan,
      'latihanBenar': latihanBenar,
      'totalAktivitas': totalAktivitas,
      'selesaiAktivitas': selesaiAktivitas,
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
      ORDER BY hasil_latihan.id DESC
      LIMIT 10
      ''',
      [DatabaseHelper.userId],
    );
  }

  // ============================================================
  // FUNGSI REFRESH
  // ============================================================

  Future<void> refreshData() async {
    // Baca ulang data dari database
    final statistikBaru = ambilStatistik();
    final historyBaru = ambilRiwayat();

    // Masukkan Future baru ke halaman
    setState(() {
      _futureStatistik = statistikBaru;
      _futureHistory = historyBaru;
    });

    // Tunggu statistik selesai dibaca
    try {
      await _futureStatistik;
      await _futureHistory;
    } catch (_) {
      // Error akan ditampilkan oleh FutureBuilder
    }

    // Pastikan halaman masih aktif
    if (!mounted) return;

    // Berikan pemberitahuan bahwa refresh berhasil
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress berhasil diperbarui'),
        duration: Duration(seconds: 1),
      ),
    );
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
      body: FutureBuilder<Map<String, int>>(
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
                  'Gagal memuat statistik:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // ----------------------------------------------------
          // DATA
          // ----------------------------------------------------

          final data = snapshot.data ?? {};

          final totalAktivitas = data['totalAktivitas'] ?? 0;

          final selesaiAktivitas = data['selesaiAktivitas'] ?? 0;

          // ----------------------------------------------------
          // HITUNG PERSENTASE PROGRESS
          // ----------------------------------------------------

          final progress = totalAktivitas == 0
              ? 0.0
              : (selesaiAktivitas / totalAktivitas).clamp(0.0, 1.0).toDouble();

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
                          'Progress Belajar',

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
                          '$selesaiAktivitas dari '
                          '$totalAktivitas aktivitas selesai',

                          style: TextStyle(color: Colors.grey[700]),
                        ),
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
                        message:
                            'Gagal memuat riwayat: '
                            '${snapshot.error}',
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

                              color: benar ? Colors.green : Colors.red,
                            ),

                            // ----------------------------------------
                            // STATUS
                            // ----------------------------------------
                            title: Text('${data['status']}'),

                            // ----------------------------------------
                            // INSTRUKSI
                            // ----------------------------------------
                            subtitle: Text('${data['instruksi']}'),
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

            Icon(icon, size: 35, color: Colors.indigo),

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

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

  static const int userId = 1;
  static const String databaseName = 'lexiflip.db';

  Database? _database;

  Future<void> initDatabase() async {
    if (_database != null) return;

    final databasePath = p.join(await getDatabasesPath(), databaseName);

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDatabase(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE pengguna (
        id INTEGER PRIMARY KEY,
        nama TEXT NOT NULL
      )
    ''');

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
      {
        'bab_id': 1,
        'judul': 'Apa itu Variabel?',
        'isi': 'Variabel adalah tempat untuk menyimpan nilai yang digunakan oleh program.',
        'contoh': 'int umur = 20;',
      },
      {
        'bab_id': 2,
        'judul': 'Tipe Data',
        'isi': 'Tipe data menentukan jenis nilai yang dapat disimpan oleh variabel.',
        'contoh': 'double nilai = 90.5;',
      },
      {
        'bab_id': 3,
        'judul': 'Percabangan IF',
        'isi': 'Percabangan digunakan untuk mengambil keputusan berdasarkan kondisi.',
        'contoh': 'if (nilai >= 75) {\n  cout << "Lulus";\n}',
      },
      {
        'bab_id': 4,
        'judul': 'Perulangan FOR',
        'isi': 'Perulangan digunakan untuk menjalankan kode beberapa kali.',
        'contoh': 'for (int i = 0; i < 5; i++) {\n  cout << i;\n}',
      },
      {
        'bab_id': 5,
        'judul': 'Array',
        'isi': 'Array digunakan untuk menyimpan beberapa data dengan tipe yang sama.',
        'contoh': 'int angka[3] = {10, 20, 30};',
      },
    ];

    for (final item in materi) {
      await db.insert('materi', item);
    }

    const flashcards = [
      {
        'bab_id': 1,
        'pertanyaan': 'Apa fungsi variabel?',
        'jawaban': 'Variabel digunakan untuk menyimpan data atau nilai.',
        'contoh': 'int umur = 20;',
      },
      {
        'bab_id': 2,
        'pertanyaan': 'Apa yang dimaksud tipe data?',
        'jawaban': 'Tipe data menentukan jenis nilai yang disimpan.',
        'contoh': 'double nilai = 90.5;',
      },
      {
        'bab_id': 3,
        'pertanyaan': 'Apa fungsi IF?',
        'jawaban': 'IF digunakan untuk menjalankan kode berdasarkan kondisi.',
        'contoh': 'if (nilai >= 75) {\n  cout << "Lulus";\n}',
      },
      {
        'bab_id': 4,
        'pertanyaan': 'Apa fungsi FOR?',
        'jawaban': 'FOR digunakan untuk melakukan perulangan.',
        'contoh': 'for (int i = 0; i < 5; i++) {\n  cout << i;\n}',
      },
      {
        'bab_id': 5,
        'pertanyaan': 'Apa itu array?',
        'jawaban': 'Array adalah kumpulan data dengan tipe yang sama.',
        'contoh': 'int angka[3] = {10, 20, 30};',
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

  Future<void> simpanNama(String nama) async {
    await database.insert('pengguna', {
      'id': userId,
      'nama': nama,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> ambilNama() async {
    final data = await database.query(
      'pengguna',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (data.isEmpty) return '';

    return '${data.first['nama'] ?? ''}';
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
// START PAGE
// ============================================================

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  String namaTersimpan = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cekPengguna();
  }

  Future<void> cekPengguna() async {
    try {
      final nama = await DatabaseHelper.instance.ambilNama();

      if (!mounted) return;

      setState(() {
        namaTersimpan = nama;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  void masuk() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DashboardPage(nama: namaTersimpan)),
    );
  }

  // EDIT NAMA PENGGUNA
  Future<void> editNama() async {
    final controller = TextEditingController(text: namaTersimpan);

    final namaBaru = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Nama Pengguna'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Pengguna',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final nama = controller.text.trim();

                if (nama.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama tidak boleh kosong.')),
                  );
                  return;
                }

                Navigator.pop(dialogContext, nama);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || namaBaru == null) return;

    try {
      await DatabaseHelper.instance.simpanNama(namaBaru);

      if (!mounted) return;

      setState(() {
        namaTersimpan = namaBaru;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama pengguna berhasil diperbarui!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengubah nama: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // PENGGUNA LAMA
    if (namaTersimpan.isNotEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // KONTEN HALAMAN MASUK
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.style_rounded,
                        size: 90,
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'LexiFlip',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Selamat datang kembali, $namaTersimpan!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: masuk,
                          icon: const Icon(Icons.login),
                          label: const Text('MASUK'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // IKON PENGATURAN DI POJOK KANAN ATAS
              Positioned(
                top: 4,
                right: 8,
                child: IconButton(
                  tooltip: 'Pengaturan nama',
                  onPressed: editNama,
                  icon: const Icon(
                    Icons.settings,
                    size: 28,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // PENGGUNA BARU
    return const WelcomePage();
  }
}
// ============================================================
// WELCOME
// ============================================================

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController namaController = TextEditingController();

  @override
  void dispose() {
    namaController.dispose();
    super.dispose();
  }

  Future<void> mulai() async {
    final nama = namaController.text.trim();

    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan masukkan nama terlebih dahulu.')),
      );
      return;
    }

    try {
      await DatabaseHelper.instance.simpanNama(nama);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan nama: $e')));

      return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DashboardPage(nama: nama)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Icon(Icons.style_rounded, size: 90, color: Colors.indigo),
                const SizedBox(height: 15),
                const Text(
                  'LexiFlip',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Belajar Dasar Pemrograman C++',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: namaController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => mulai(),
                  decoration: const InputDecoration(
                    labelText: 'Nama Pengguna',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: mulai,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('MULAI'),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal menyimpan status: $e')),
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
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
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

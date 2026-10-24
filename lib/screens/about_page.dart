import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: ListView(
        key: const PageStorageKey<String>('about-page'),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          Icon(Icons.style_rounded, size: 84, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'LexiFlip',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Aplikasi Pembelajaran Dasar Pemrograman C++',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Versi 1.0.0',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'LexiFlip membantu pengguna mempelajari konsep dasar '
                'pemrograman C++ melalui materi pembelajaran, flashcard, '
                'dan latihan kode.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Teknologi yang Digunakan',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.widgets_outlined),
                  title: Text('Flutter'),
                ),
                Divider(height: 1),
                ListTile(leading: Icon(Icons.code), title: Text('Dart')),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('SQLite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _windowsFactoryInitialized = false;

Future<void> initializeDatabasePlatform() async {
  if (Platform.isWindows && !_windowsFactoryInitialized) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _windowsFactoryInitialized = true;
  }
}

Future<String> databasePathFor(String databaseName) async {
  if (Platform.isWindows) {
    final supportDirectory = await getApplicationSupportDirectory();
    final databasesDirectory = Directory(
      p.join(supportDirectory.path, 'databases'),
    );
    await databasesDirectory.create(recursive: true);
    return p.join(databasesDirectory.path, databaseName);
  }

  return p.join(await getDatabasesPath(), databaseName);
}

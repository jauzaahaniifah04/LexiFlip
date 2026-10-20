import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

bool _webFactoryInitialized = false;

Future<void> initializeDatabasePlatform() async {
  if (!_webFactoryInitialized) {
    databaseFactory = databaseFactoryFfiWeb;
    _webFactoryInitialized = true;
  }
}

Future<String> databasePathFor(String databaseName) async => databaseName;

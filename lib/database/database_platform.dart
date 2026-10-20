import 'database_platform_web.dart'
    if (dart.library.io) 'database_platform_io.dart'
    as platform;

Future<void> initializeDatabasePlatform() =>
    platform.initializeDatabasePlatform();

Future<String> databasePathFor(String databaseName) =>
    platform.databasePathFor(databaseName);

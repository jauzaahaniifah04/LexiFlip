# LexiFlip

LexiFlip is a Flutter learning app that stores accounts, preferences, lessons,
flashcards, exercises, and learning progress in SQLite.

## Database platforms

- Android uses the native SQLite implementation provided by `sqflite`. Its
  existing database location and schema migrations are retained.
- Windows initializes `sqflite_common_ffi` before opening the database and
  stores `lexiflip.db` in the app's support directory.
- Web uses SQLite compiled to WebAssembly with `sqflite_common_ffi_web`.
  Browser data is persisted in IndexedDB for the current site origin. A
  different development port is a different browser database.

The Web backend is experimental and requires the SQLite WASM file and shared
worker alongside the deployed app. After dependency installation, generate
these files with:

```powershell
flutter pub get
dart run sqflite_common_ffi_web:setup
```

Keep `web/sqlite3.wasm` and `web/sqflite_sw.js` in the project and deploy them
at the root of the Web app. Run the setup command again after upgrading
`sqflite_common_ffi_web` or `sqlite3`.

## Run LexiFlip

Install Flutter and the toolchain for the platform you want to run. List
available devices with:

```powershell
flutter devices
```

Run on an Android Emulator or connected Android phone (replace the ID with
one shown by `flutter devices`):

```powershell
flutter run -d <android-device-id>
```

Run in Chrome or Microsoft Edge:

```powershell
flutter run -d chrome
flutter run -d edge
```

Run on Windows Desktop:

```powershell
flutter run -d windows
```

Windows Desktop requires Visual Studio with the **Desktop development with
C++** workload, a Windows SDK, and Windows Developer Mode (Flutter plugins
need symlink support).

## Verify

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build web
flutter build windows
```

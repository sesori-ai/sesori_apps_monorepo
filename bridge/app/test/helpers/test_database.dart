import "package:drift/native.dart";
import "package:sesori_bridge/src/api/database/database.dart";

export "single_plugin_repository_test_support.dart";

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

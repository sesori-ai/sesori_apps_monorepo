import "package:drift/native.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

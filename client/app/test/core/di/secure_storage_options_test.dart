import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/di/register_module.dart";

void main() {
  test("native options disable destructive Android reset without changing legacy namespaces", () {
    final storage = _RegisterModule().secureStorage;

    expect(storage.aOptions.toMap(), const AndroidOptions(resetOnError: false).toMap());
    expect(storage.iOptions.toMap(), IOSOptions.defaultOptions.toMap());
    expect(storage.mOptions.toMap(), const MacOsOptions(accountName: "Sesori").toMap());
  });
}

class _RegisterModule() extends RegisterModule;

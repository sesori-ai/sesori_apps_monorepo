import "package:get_it/get_it.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  test("configureDesktopCoreDependencies completes on a fresh container", () {
    final GetIt getIt = GetIt.asNewInstance();

    expect(() => configureDesktopCoreDependencies(getIt), returnsNormally);
  });
}

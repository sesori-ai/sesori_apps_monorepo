import "dart:async";

import "package:sesori_bridge/src/listeners/catalog_import_console_listener.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("catalog import console listener owns one subscription", () async {
    var listenCount = 0;
    var cancelCount = 0;
    final controller = StreamController<CatalogImportProgress>.broadcast(
      onListen: () => listenCount++,
      onCancel: () => cancelCount++,
    );
    final listener = CatalogImportConsoleListener(progress: controller.stream);

    listener.start();
    listener.start();
    expect(listenCount, 1);

    await listener.dispose();
    await listener.dispose();
    expect(cancelCount, 1);
    await controller.close();
  });
}

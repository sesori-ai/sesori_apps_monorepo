import "dart:async";
import "dart:io";

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

  group("completion line", () {
    Future<String> lineFor(CatalogImportNewItems? newItems) async {
      final lines = <String>[];
      final controller = StreamController<CatalogImportProgress>.broadcast();
      final listener = CatalogImportConsoleListener(progress: controller.stream);
      await IOOverrides.runZoned(
        () async {
          listener.start();
          controller.add(
            CatalogImportProgress.completed(
              pluginId: "codex",
              projectsImported: 43,
              sessionsImported: 193,
              newItems: newItems,
              completedAt: 1,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        stdout: () => _CapturingStdout(lines),
      );
      await listener.dispose();
      await controller.close();
      return lines.single;
    }

    test("reports the delta alongside the totals", () async {
      expect(
        await lineFor(const CatalogImportNewItems(projects: 2, sessions: 5)),
        "Imported codex catalog: 43 project(s), 193 session(s). 2 new project(s), 5 new session(s).",
      );
    });

    test("says nothing new when the delta is zero", () async {
      expect(
        await lineFor(const CatalogImportNewItems(projects: 0, sessions: 0)),
        "Imported codex catalog: 43 project(s), 193 session(s). Nothing new.",
      );
    });

    test("leaves the totals to stand alone when the delta is absent", () async {
      // An absent delta means the producer does not report one. Printing
      // "Nothing new" here would claim a fact the bridge never sent.
      expect(
        await lineFor(null),
        "Imported codex catalog: 43 project(s), 193 session(s).",
      );
    });
  });
}

class _CapturingStdout(final List<String> _lines) implements Stdout {
  @override
  void writeln([Object? object = ""]) => _lines.add(object.toString());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

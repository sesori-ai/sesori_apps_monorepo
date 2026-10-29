import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late _Projects projects;
  late _Window window;
  late FakeCatalogRescanService rescan;
  late SessionListRefreshService service;
  setUp(() {
    projects = _Projects();
    window = _Window();
    rescan = FakeCatalogRescanService();
    service = SessionListRefreshService(
      projectInventory: projects,
      window: window,
      catalogRescanService: rescan,
    );
  });
  tearDown(() => rescan.onDispose());

  test("a refresh imports and waits for projects, then reloads the window once", () async {
    final projectReply = Completer<bool>();
    final sessionReply = Completer<bool>();
    when(projects.refreshProjects).thenAnswer((_) => projectReply.future);
    when(window.reload).thenAnswer((_) => sessionReply.future);
    var settled = false;
    final refresh = service.refresh().then((result) {
      settled = true;
      return result;
    });
    expect(rescan.startAllCalls, 1);
    verify(projects.refreshProjects).called(1);
    verifyNever(window.reload);
    projectReply.complete(true);
    await Future<void>.delayed(Duration.zero);
    verify(window.reload).called(1);
    expect(settled, isFalse);
    sessionReply.complete(true);
    expect(await refresh, isTrue);
  });

  for (final results in [
    (projects: false, window: true),
    (projects: true, window: false),
    (projects: false, window: false),
  ]) {
    test("projects and the window are both attempted and failure is combined: $results", () async {
      when(projects.refreshProjects).thenAnswer((_) async => results.projects);
      when(window.reload).thenAnswer((_) async => results.window);
      expect(await service.refresh(), isFalse);
      verifyInOrder([projects.refreshProjects, window.reload]);
      expect(rescan.startAllCalls, 1, reason: "a failed reload still imports");
    });
  }

  for (final failProject in [true, false]) {
    test("unexpected failure retains diagnostics (project phase: $failProject)", () async {
      final sink = _LogSink();
      final previousLevel = logLevel;
      setLogLevel(LogLevel.debug);
      setLogSink(sink: sink);
      addTearDown(() {
        setLogSink(sink: const StdoutLogSink());
        setLogLevel(previousLevel);
      });
      final error = StateError("fixture read failed");
      final stack = StackTrace.current;
      when(projects.refreshProjects).thenAnswer((_) => failProject ? Future.error(error, stack) : Future.value(true));
      when(window.reload).thenAnswer((_) => Future.error(error, stack));
      expect(await service.refresh(), isFalse);
      expect(sink.records.single.level, LogLevel.error);
      expect(sink.records.single.message, contains("session list refresh"));
      expect(sink.records.single.diagnosticError, contains("fixture read failed"));
      expect(sink.records.single.stackTrace, same(stack));
      if (failProject) verifyNever(window.reload);
    });
  }

  test("scan is the import's state", () {
    const failed = CatalogRescanState.failed(failedPluginIds: {"codex"});
    rescan.emit(failed);
    expect(service.scan.value, same(failed));
  });
}

class _Projects() extends Mock implements ProjectInventoryService;

class _Window() extends Mock implements SessionWindowService;

class _LogSink() implements LogSink {
  final records = <LogRecord>[];
  @override
  void write({required LogRecord record}) => records.add(record);
  @override
  Future<void> flush() async {}
}

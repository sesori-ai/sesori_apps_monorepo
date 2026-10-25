import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  late _Service service;
  late BehaviorSubject<CatalogRescanState> scan;
  setUp(() {
    service = _Service();
    scan = BehaviorSubject.seeded(const CatalogRescanState.idle());
    when(() => service.scan).thenAnswer((_) => scan.stream);
  });
  tearDown(() => scan.close());

  for (final reloaded in [true, false]) {
    test("refresh reports the reload outcome: $reloaded", () async {
      final reply = Completer<bool>();
      when(service.refresh).thenAnswer((_) => reply.future);
      final cubit = SessionListRefreshCubit(service: service);
      addTearDown(cubit.close);
      expect(cubit.state.status, SessionListRefreshStatus.idle);
      final refresh = cubit.refresh();
      expect(cubit.state.status, SessionListRefreshStatus.refreshing);
      reply.complete(reloaded);
      expect(await refresh, reloaded);
      expect(
        cubit.state.status,
        reloaded ? SessionListRefreshStatus.succeeded : SessionListRefreshStatus.failed,
      );
    });
  }

  test("a refresh while one runs joins it", () async {
    final reply = Completer<bool>();
    when(service.refresh).thenAnswer((_) => reply.future);
    final cubit = SessionListRefreshCubit(service: service);
    addTearDown(cubit.close);
    final first = cubit.refresh();
    final second = cubit.refresh();
    reply.complete(true);
    expect(await first, isTrue);
    expect(await second, isTrue);
    verify(service.refresh).called(1);
  });

  test("projects the import state and keeps the reload status", () async {
    when(service.refresh).thenAnswer((_) async => true);
    const failed = CatalogRescanState.partlyFailed(succeededCount: 1, failedPluginIds: {"codex"});
    scan.add(const CatalogRescanState.noHarness());
    final cubit = SessionListRefreshCubit(service: service);
    addTearDown(cubit.close);
    expect(cubit.state.scan, isA<CatalogRescanNoHarness>());
    await cubit.refresh();
    scan.add(failed);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.scan, same(failed));
    expect(cubit.state.status, SessionListRefreshStatus.succeeded);
  });
}

class _Service() extends Mock implements SessionListRefreshService;

import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime_server_exception.dart";
import "package:sesori_bridge/src/runtime/plugin_generation_factory.dart";
import "package:sesori_bridge/src/runtime/plugin_runtime.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _testHostJsonStore = _UnusedHostJsonStore();

void main() {
  test("snapshot emissions cannot be mutated by subscribers", () async {
    final runtime = _runtime(factory: _FakeGenerationFactory(startGate: Future<void>.value()));
    addTearDown(runtime.dispose);

    final snapshots = await runtime.snapshots.first;

    expect(snapshots.clear, throwsUnsupportedError);
    expect((await runtime.snapshots.first).single.pluginId, "one");
  });

  test("only the latest setup inspection can update a slot", () async {
    final firstGate = Completer<PluginSetupStatus>();
    final secondGate = Completer<PluginSetupStatus>();
    final gates = [firstGate, secondGate];
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
      descriptor: _FakeDescriptor(inspect: () => gates.removeAt(0).future),
    );
    addTearDown(runtime.dispose);

    final first = runtime.inspectSetup(pluginIds: const {"one"}, markUnselectedNotInspected: false);
    final second = runtime.inspectSetup(pluginIds: const {"one"}, markUnselectedNotInspected: false);
    secondGate.complete(const PluginSetupReady());
    expect((await second)["one"], isA<PluginSetupReady>());
    firstGate.complete(const PluginSetupRuntimeMissing(actionHint: "stale"));

    expect((await first)["one"], isA<PluginSetupReady>());
    expect(runtime.snapshot.single.setup, isA<PluginSetupReady>());
  });

  test("installRuntime forwards descriptor progress and aborts on shutdown", () async {
    final installGate = Completer<void>();
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
      descriptor: _FakeDescriptor(
        install: (startAborted) async* {
          yield const ProvisionResolving();
          await installGate.future;
          if (startAborted.isAborted) throw const PluginStartAbortedException();
          yield const ProvisionReady(binaryPath: "/managed/one");
        },
      ),
    );
    addTearDown(runtime.dispose);

    final events = <RuntimeProvisionProgress>[];
    final done = runtime.installRuntime(pluginId: "one").listen(events.add).asFuture<void>();
    await Future<void>.delayed(Duration.zero);
    expect(events.single, isA<ProvisionResolving>());

    runtime.beginShutdown();
    installGate.complete();
    await expectLater(done, throwsA(isA<PluginStartAbortedException>()));
  });

  test("installRuntime fails immediately while shutting down", () async {
    final runtime = _runtime(factory: _FakeGenerationFactory(startGate: Future<void>.value()));
    addTearDown(runtime.dispose);

    runtime.beginShutdown();
    final events = await runtime.installRuntime(pluginId: "one").toList();

    expect(events.single, isA<ProvisionFailed>());
  });

  test("authenticate forwards safe events and aborts on shutdown", () async {
    final authenticationGate = Completer<void>();
    final authenticationStores = <HostJsonStore>[];
    final descriptor = _AuthenticationDescriptor(
      authenticate: ({required aborted}) async* {
        yield PluginAuthenticationDeviceCodeChallenge(
          verificationUri: Uri.parse("https://auth.example/device"),
          userCode: "ABCD-EFGH",
        );
        await authenticationGate.future;
        if (aborted.isAborted) throw const PluginStartAbortedException();
        yield const PluginAuthenticationCompleted();
      },
      kind: const PluginAuthenticationDeviceCodeOperationKind(),
      recordStore: ({required store}) => authenticationStores.add(store),
    );
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
      descriptor: descriptor,
    );
    addTearDown(runtime.dispose);
    final events = <PluginAuthenticationEvent>[];
    final operation = runtime.authenticate(pluginId: "one");
    final done = operation.events.listen(events.add).asFuture<void>();
    await Future<void>.delayed(Duration.zero);

    expect(events.single, isA<PluginAuthenticationDeviceCodeChallenge>());
    expect(identical(authenticationStores.single, _testHostJsonStore), isTrue);
    final wrongKind = await runtime.submitAuthenticationRedirect(
      pluginId: "one",
      generation: operation.generation,
      redirectUri: Uri.parse("http://127.0.0.1/callback?code=code"),
    );
    expect(
      wrongKind,
      isA<PluginRuntimeAuthenticationContinuationConflict>().having(
        (result) => result.reason,
        "reason",
        PluginRuntimeAuthenticationContinuationConflictReason.wrongKind,
      ),
    );

    runtime.beginShutdown();
    final shutdownSubmission = await runtime.submitAuthenticationRedirect(
      pluginId: "one",
      generation: operation.generation,
      redirectUri: Uri.parse("http://127.0.0.1/callback?code=code"),
    );
    expect(
      shutdownSubmission,
      isA<PluginRuntimeAuthenticationContinuationConflict>().having(
        (result) => result.reason,
        "reason",
        PluginRuntimeAuthenticationContinuationConflictReason.staleGeneration,
      ),
    );
    authenticationGate.complete();
    await expectLater(done, throwsA(isA<PluginStartAbortedException>()));
  });

  test("browser redirects are one-shot and fenced to the active generation", () async {
    final streams = [StreamController<PluginAuthenticationEvent>(), StreamController<PluginAuthenticationEvent>()];
    var streamIndex = 0;
    final submitted = <Uri>[];
    final descriptor = _AuthenticationDescriptor(
      authenticate: ({required aborted}) => streams[streamIndex++].stream,
      kind: PluginAuthenticationBrowserOperationKind(
        submitRedirect: ({required redirectUri}) async => submitted.add(redirectUri),
      ),
      recordStore: ({required store}) {},
    );
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
      descriptor: descriptor,
    );
    addTearDown(runtime.dispose);

    final first = runtime.authenticate(pluginId: "one");
    expect(() => runtime.authenticate(pluginId: "one"), throwsStateError);
    final firstDone = first.events.drain<void>();
    streams.first.add(
      PluginAuthenticationBrowserChallenge(
        authorizationUri: Uri.parse("https://accounts.example/authorize"),
        expectedCallbackUri: Uri.parse("http://127.0.0.1/callback"),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final firstRedirect = Uri.parse("http://127.0.0.1/callback?code=first");
    expect(
      await runtime.submitAuthenticationRedirect(
        pluginId: "one",
        generation: first.generation,
        redirectUri: firstRedirect,
      ),
      isA<PluginRuntimeAuthenticationContinuationApplied>(),
    );
    final duplicate = await runtime.submitAuthenticationRedirect(
      pluginId: "one",
      generation: first.generation,
      redirectUri: firstRedirect,
    );
    expect(
      duplicate,
      isA<PluginRuntimeAuthenticationContinuationConflict>().having(
        (result) => result.reason,
        "reason",
        PluginRuntimeAuthenticationContinuationConflictReason.alreadySubmitted,
      ),
    );
    await streams.first.close();
    await firstDone;

    final second = runtime.authenticate(pluginId: "one");
    final secondDone = second.events.drain<void>();
    final secondRedirect = Uri.parse("http://127.0.0.1/callback?code=second");
    final stale = await runtime.submitAuthenticationRedirect(
      pluginId: "one",
      generation: first.generation,
      redirectUri: firstRedirect,
    );
    expect(
      stale,
      isA<PluginRuntimeAuthenticationContinuationConflict>().having(
        (result) => result.reason,
        "reason",
        PluginRuntimeAuthenticationContinuationConflictReason.staleGeneration,
      ),
    );
    expect(
      await runtime.submitAuthenticationRedirect(
        pluginId: "one",
        generation: second.generation,
        redirectUri: secondRedirect,
      ),
      isA<PluginRuntimeAuthenticationContinuationApplied>(),
    );
    expect(submitted, [firstRedirect, secondRedirect]);

    second.abort();
    final afterCancel = await runtime.submitAuthenticationRedirect(
      pluginId: "one",
      generation: second.generation,
      redirectUri: secondRedirect,
    );
    expect(
      afterCancel,
      isA<PluginRuntimeAuthenticationContinuationConflict>().having(
        (result) => result.reason,
        "reason",
        PluginRuntimeAuthenticationContinuationConflictReason.staleGeneration,
      ),
    );
    await streams.last.close();
    await secondDone;
  });

  test("authenticate rejects descriptors without the optional capability", () {
    final runtime = _runtime(factory: _FakeGenerationFactory(startGate: Future<void>.value()));
    addTearDown(runtime.dispose);

    expect(
      () => runtime.authenticate(pluginId: "one"),
      throwsA(isA<StateError>()),
    );
  });

  test("disable invalidates an in-flight setup inspection", () async {
    final inspectionGate = Completer<PluginSetupStatus>();
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
      descriptor: _FakeDescriptor(inspect: () => inspectionGate.future),
    );
    addTearDown(runtime.dispose);
    final inspection = runtime.inspectSetup(pluginIds: const {"one"}, markUnselectedNotInspected: false);

    await runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.safe);
    inspectionGate.complete(const PluginSetupReady());
    await inspection;

    expect(runtime.snapshot.single.setup, isA<PluginSetupUnknown>());
    runtime.rollbackDisable(pluginId: "one");
  });

  test("authentication loss invalidates an in-flight setup inspection", () async {
    final inspectionGate = Completer<PluginSetupStatus>();
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
      descriptor: _FakeDescriptor(inspect: () => inspectionGate.future),
    );
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final inspection = runtime.inspectSetup(pluginIds: const {"one"}, markUnselectedNotInspected: false);

    await expectLater(
      runtime.use<void>(
        pluginId: "one",
        operation: _TestOperation.use,
        body: (_) => throw const PluginAuthenticationRequiredException(
          "test",
          actionHint: "Authenticate locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );
    inspectionGate.complete(const PluginSetupReady());
    await inspection;

    expect(runtime.snapshot.single.setup, isA<PluginSetupAuthenticationRequired>());
  });

  test("a generation change invalidates an in-flight setup inspection", () async {
    final inspectionGate = Completer<PluginSetupStatus>();
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
      descriptor: _FakeDescriptor(inspect: () => inspectionGate.future),
    );
    addTearDown(runtime.dispose);
    final inspection = runtime.inspectSetup(pluginIds: const {"one"}, markUnselectedNotInspected: false);

    await runtime.start(pluginId: "one");
    inspectionGate.complete(const PluginSetupRuntimeMissing(actionHint: "stale"));
    await inspection;

    expect(runtime.snapshot.single.setup, isA<PluginSetupUnknown>());
  });

  test("access refresh cannot restore start permission after authentication loss", () async {
    final runtime = _runtime(factory: _FakeGenerationFactory(startGate: Future<void>.value()));
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    await expectLater(
      runtime.use<void>(
        pluginId: "one",
        operation: _TestOperation.use,
        body: (_) => throw const PluginAuthenticationRequiredException(
          "test",
          actionHint: "Authenticate locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );
    runtime.applyAccess(
      entries: const [
        PluginRuntimeAccess(
          pluginId: "one",
          gate: PluginRuntimeAccessGate.enabled,
          startAllowed: true,
        ),
      ],
    );

    expect(runtime.snapshot.single.startAllowed, isFalse);
  });

  test("unknown plugin acquisitions preserve the typed unavailable contract", () async {
    final runtime = _runtime(
      factory: _FakeGenerationFactory(startGate: Future<void>.value()),
    );
    addTearDown(runtime.dispose);

    Matcher unavailableFor(String operation) => isA<PluginOperationException>()
        .having((error) => error.operation, "operation", operation)
        .having((error) => error.statusCode, "statusCode", 503)
        .having((error) => error.message, "message", contains("unknown"));

    await expectLater(
      runtime.use(pluginId: "removed-plugin", operation: _TestOperation.read, body: (_) async {}),
      throwsA(unavailableFor("read")),
    );
    await expectLater(
      runtime.useWithGeneration(
        pluginId: "removed-plugin",
        operation: _TestOperation.capture,
        body: (_) async {},
      ),
      throwsA(unavailableFor("capture")),
    );
    await expectLater(
      runtime.useStream<int>(
        pluginId: "removed-plugin",
        operation: _TestOperation.watch,
        body: (_, _) => const Stream<int>.empty(),
      ),
      emitsError(unavailableFor("watch")),
    );
    await expectLater(
      runtime.useIfActive<void>(
        pluginId: "removed-plugin",
        operation: _TestOperation.activeRead,
        body: (_, _) async {},
      ),
      throwsA(unavailableFor("activeRead")),
    );
    expect(
      () => runtime.requireCurrentGeneration(
        pluginId: "removed-plugin",
        generation: 1,
        operation: _TestOperation.directFence,
      ),
      throwsA(
        isA<PluginOperationException>()
            .having((error) => error.operation, "operation", "directFence")
            .having((error) => error.statusCode, "statusCode", 503),
      ),
    );
  });

  test("useWithGeneration activates, returns the acquired generation, and releases its lease", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    expect(
      await runtime.stop(pluginId: "one", intent: PluginStopIntent.safe),
      isA<PluginRuntimeCommandApplied>(),
    );
    BridgePluginApi? bodyApi;

    final result = await runtime.useWithGeneration(
      pluginId: "one",
      operation: _TestOperation.capture,
      body: (api) async {
        bodyApi = api;
        expect(runtime.snapshot.single.leaseCount, 1);
        return "captured";
      },
    );

    expect(factory.startCount, 2);
    expect(bodyApi, same(factory.api));
    expect(result, (value: "captured", generation: 2));
    expect(runtime.snapshot.single.leaseCount, 0);
  });

  test("useWithGeneration handles authentication loss and releases its lease", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await expectLater(
      runtime.useWithGeneration<void>(
        pluginId: "one",
        operation: _TestOperation.capture,
        body: (_) => throw const PluginAuthenticationRequiredException(
          "test",
          actionHint: "Authenticate locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );
    await _waitUntil(
      () => runtime.snapshot.single.state == PluginRuntimeState.blocked && factory.plugins.single.shutdownCount == 1,
    );

    expect(runtime.snapshot.single.setup, isA<PluginSetupAuthenticationRequired>());
    expect(runtime.snapshot.single.leaseCount, 0);
  });

  test("useWithGeneration checks the acquired generation before returning and releases its lease", () async {
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final operation = runtime.useWithGeneration(
      pluginId: "one",
      operation: _TestOperation.capture,
      body: (_) async {
        await operationGate.future;
        return "stale";
      },
    );
    final operationExpectation = expectLater(
      operation,
      throwsA(
        isA<PluginOperationException>().having((error) => error.operation, "operation", "capture"),
      ),
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1);

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.force);
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);
    operationGate.complete();

    await operationExpectation;
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(runtime.snapshot.single.leaseCount, 0);
  });

  test("concurrent acquisitions join one start and hold independent leases", () async {
    final startGate = Completer<void>();
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: startGate.future);
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    final first = runtime.use(
      pluginId: "one",
      operation: _TestOperation.first,
      body: (_) => operationGate.future,
    );
    final second = runtime.use(
      pluginId: "one",
      operation: _TestOperation.second,
      body: (_) => operationGate.future,
    );
    await Future<void>.delayed(Duration.zero);

    expect(factory.startCount, 1);
    startGate.complete();
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 2);
    expect(runtime.activePluginIds, {"one"});

    operationGate.complete();
    await Future.wait([first, second]);
    expect(runtime.snapshot.single.leaseCount, 0);
  });

  test("stream acquisition retains its lease until cancellation", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final source = StreamController<int>();

    final subscription = runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) => source.stream,
        )
        .listen((_) {});
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);

    await subscription.cancel();
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 0);
    await source.close();
  });

  test("stream acquisition releases its lease and cancels its source after an error", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final source = StreamController<int>();
    final cancelled = Completer<void>();
    source.onCancel = cancelled.complete;

    final error = StateError("source failed");
    final completion = expectLater(
      runtime.useStream(
        pluginId: "one",
        operation: _TestOperation.stream,
        body: (_, _) => source.stream,
      ),
      emitsError(same(error)),
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);

    source.addError(error);

    await completion;
    await cancelled.future;
    expect(runtime.snapshot.single.leaseCount, 0);
    await source.close();
  });

  test("stream cancellation releases its lease when source cancellation fails", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final cancellationError = StateError("cancel failed");
    final source = StreamController<int>(
      onCancel: () => Future<void>.error(cancellationError),
    );
    final subscription = runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) => source.stream,
        )
        .listen((_) {});
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);

    await expectLater(subscription.cancel(), throwsA(same(cancellationError)));

    expect(runtime.snapshot.single.leaseCount, 0);
    await source.close();
  });

  test("stream cancellation before acquisition releases the eventual lease", () async {
    final startGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: startGate.future);
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    var bodyCalled = false;
    final subscription = runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) {
            bodyCalled = true;
            return const Stream<int>.empty();
          },
        )
        .listen((_) {});
    await _waitUntil(() => factory.startCount == 1);

    await subscription.cancel();
    startGate.complete();
    await _waitUntil(
      () => runtime.snapshot.single.state == PluginRuntimeState.active && runtime.snapshot.single.leaseCount == 0,
    );

    expect(bodyCalled, isFalse);
  });

  test("generation teardown cancels active operation streams and releases their leases", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final source = StreamController<int>();
    final sourceCancelled = Completer<void>();
    source.onCancel = sourceCancelled.complete;
    final completion = expectLater(
      runtime.useStream(
        pluginId: "one",
        operation: _TestOperation.stream,
        body: (_, _) => source.stream,
      ),
      emitsDone,
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);

    expect(
      await runtime.stop(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandApplied>(),
    );

    await sourceCancelled.future;
    await completion;
    expect(runtime.snapshot.single.leaseCount, 0);
    await source.close();
  });

  test("generation teardown does not wait for a paused operation stream consumer", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final source = StreamController<int>();
    final sourceCancelled = Completer<void>();
    source.onCancel = sourceCancelled.complete;
    final subscription = runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) => source.stream,
        )
        .listen((_) {});
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1 && source.hasListener);
    subscription.pause();

    final result = await runtime
        .stop(pluginId: "one", intent: PluginStopIntent.force)
        .timeout(const Duration(seconds: 1));

    expect(result, isA<PluginRuntimeCommandApplied>());
    await sourceCancelled.future;
    expect(runtime.snapshot.single.leaseCount, 0);
    subscription.resume();
    await subscription.cancel();
    await source.close();
  });

  test("revoking start permission removes an active generation from routing", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    runtime.applyAccess(
      entries: const [
        PluginRuntimeAccess(pluginId: "one", gate: PluginRuntimeAccessGate.enabled, startAllowed: false),
      ],
    );

    expect(runtime.activePluginIds, isEmpty);
    expect(runtime.isCurrentGeneration(pluginId: "one", generation: 1), isFalse);
    expect(
      await runtime.useIfActive(
        pluginId: "one",
        operation: _TestOperation.activeRead,
        body: (_, _) async => "unexpected",
      ),
      isNull,
    );
  });

  test("a safe stop blocks acquisitions once its transition begins", () async {
    final shutdownGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(api: _FakeApi(), shutdownGate: shutdownGate.future),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);

    await expectLater(
      runtime.use(pluginId: "one", operation: _TestOperation.duringStop, body: (_) async {}),
      throwsA(isA<PluginOperationException>()),
    );

    shutdownGate.complete();
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
  });

  test("a safe stop refuses busy backend work", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    factory.plugins.single.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);

    final result = await runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);

    expect(result, isA<PluginRuntimeCommandConflict>());
    expect((result as PluginRuntimeCommandConflict).reasons, contains(PluginRuntimeConflictReason.busy));
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);
  });

  test("shutdown interrupt asks every started plugin to quiesce active work within the budget", () async {
    final api = _FakeApi();
    late _FakePlugin plugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => plugin = _FakePlugin(api: api),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    Duration? seenBudget;
    plugin.interruptActiveWorkHandler = (budget) async {
      seenBudget = budget;
      return const {};
    };

    await runtime.interruptActiveWorkForShutdown();

    expect(plugin.interruptActiveWorkCount, 1);
    expect(seenBudget, const Duration(seconds: 1));
  });

  test("shutdown interrupt isolates a failing plugin and never throws", () async {
    final api = _FakeApi();
    late _FakePlugin plugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => plugin = _FakePlugin(api: api),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    plugin.interruptActiveWorkHandler = (_) => Future.error(StateError("cannot quiesce"));

    await runtime.interruptActiveWorkForShutdown();

    expect(plugin.interruptActiveWorkCount, 1);
  });

  test("shutdown interrupt bounds a hung plugin", () async {
    final api = _FakeApi();
    late _FakePlugin plugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => plugin = _FakePlugin(api: api),
    );
    final runtime = _runtime(
      factory: factory,
      shutdownBudget: const Duration(milliseconds: 20),
    );
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    plugin.interruptActiveWorkHandler = (_) => Completer<Set<String>>().future;

    await runtime.interruptActiveWorkForShutdown();

    expect(plugin.interruptActiveWorkCount, 1);
  });

  test("a force stop interrupts active sessions before retiring the generation", () async {
    final api = _FakeApi(
      activeSessionsSummary: const [
        PluginProjectActivitySummary(
          id: "project",
          activeSessions: [
            PluginActiveSession(
              id: "snapshot",
              mainAgentRunning: true,
              childSessionIds: ["snapshot-child"],
            ),
          ],
        ),
      ],
    );
    late _FakePlugin plugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => plugin = _FakePlugin(api: api),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    plugin.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);
    final events = <SourcedPluginRuntimeEvent>[];
    final eventSubscription = runtime.backendEvents.listen((event) {
      events.add(event);
      final consumed = event.terminalHandoffConsumed;
      if (consumed != null && !consumed.isCompleted) consumed.complete();
    });
    plugin.interruptActiveWorkHandler = (budget) async {
      plugin.workStates.add(PluginWorkState.idle);
      return {"busy", "retry"};
    };

    final result = await runtime.stop(pluginId: "one", intent: PluginStopIntent.force);

    expect(result, isA<PluginRuntimeCommandApplied>());
    expect(plugin.interruptActiveWorkCount, 1);
    expect(
      events,
      everyElement(
        isA<SourcedPluginRuntimeEvent>().having((event) => event.allowDuringStop, "allowDuringStop", isTrue),
      ),
    );
    final handoffEvents = events.map((event) => (event.event as BridgeSseTerminalHandoff).event).toList();
    expect(
      handoffEvents.whereType<BridgeSseSessionIdle>().map((event) => event.sessionID),
      unorderedEquals(["snapshot", "snapshot-child", "busy", "retry"]),
    );
    expect(handoffEvents.whereType<BridgeSseProjectUpdated>(), hasLength(1));
    expect(runtime.isCurrentGeneration(pluginId: "one", generation: 1), isFalse);
    expect(runtime.isCurrentEventGeneration(pluginId: "one", generation: 1), isTrue);
    expect(
      runtime.isCurrentEvent(
        pluginId: "one",
        generation: 1,
        allowDuringStop: true,
      ),
      isTrue,
    );
    expect(
      runtime.isCurrentEvent(
        pluginId: "one",
        generation: 1,
        allowDuringStop: false,
      ),
      isFalse,
    );

    await runtime.start(pluginId: "one");
    expect(runtime.isCurrentEventGeneration(pluginId: "one", generation: 1), isFalse);
    await eventSubscription.cancel();
  });

  test("a failed interruption does not synthesize idle handoff", () async {
    final api = _FakeApi(
      activeSessionsSummary: const [
        PluginProjectActivitySummary(
          id: "project",
          activeSessions: [PluginActiveSession(id: "busy", mainAgentRunning: true)],
        ),
      ],
    );
    late _FakePlugin plugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => plugin = _FakePlugin(api: api),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    plugin.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);
    final events = <SourcedPluginRuntimeEvent>[];
    final eventSubscription = runtime.backendEvents.listen(events.add);
    plugin.interruptActiveWorkHandler = (_) => Future.error(StateError("cannot quiesce"));

    expect(
      await runtime.stop(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandApplied>(),
    );

    expect(plugin.interruptActiveWorkCount, 1);
    expect(events, isEmpty);
    await eventSubscription.cancel();
  });

  test("a force stop reconciles the pre-barrier snapshot when work naturally becomes idle", () async {
    final api = _FakeApi(
      activeSessionsSummary: const [
        PluginProjectActivitySummary(
          id: "project",
          activeSessions: [
            PluginActiveSession(
              id: "root",
              mainAgentRunning: true,
              childSessionIds: ["child"],
            ),
          ],
        ),
      ],
    );
    late _FakePlugin plugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => plugin = _FakePlugin(api: api),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    plugin.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);
    final operationStarted = Completer<void>();
    final operationGate = Completer<void>();
    final operation = runtime.use<void>(
      pluginId: "one",
      operation: _TestOperation.use,
      body: (_) async {
        operationStarted.complete();
        await operationGate.future;
      },
    );
    final operationCompletion = expectLater(operation, throwsA(isA<PluginOperationException>()));
    await operationStarted.future;
    final events = <SourcedPluginRuntimeEvent>[];
    final eventSubscription = runtime.backendEvents.listen((event) {
      events.add(event);
      final consumed = event.terminalHandoffConsumed;
      if (consumed != null && !consumed.isCompleted) consumed.complete();
    });

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.force);
    await _waitUntil(() => api.getActiveSessionsSummaryCount == 1);
    plugin.workStates.add(PluginWorkState.idle);
    operationGate.complete();
    await operationCompletion;

    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(plugin.interruptActiveWorkCount, 0);
    final handoffEvents = events.map((event) => (event.event as BridgeSseTerminalHandoff).event).toList();
    expect(
      handoffEvents.whereType<BridgeSseSessionIdle>().map((event) => event.sessionID),
      unorderedEquals(["root", "child"]),
    );
    expect(handoffEvents.last, isA<BridgeSseProjectUpdated>());
    expect(events.last.terminalHandoffConsumed, isNotNull);

    await eventSubscription.cancel();
  });

  test("only pending-input resolutions emitted during interruption are authorized", () async {
    final api = _FakeApi();
    late _FakePlugin plugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => plugin = _FakePlugin(api: api),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    final events = <SourcedPluginRuntimeEvent>[];
    final sentinelArrived = Completer<SourcedPluginRuntimeEvent>();
    final eventSubscription = runtime.backendEvents.listen((event) {
      events.add(event);
      if (event.terminalHandoffConsumed != null && !sentinelArrived.isCompleted) {
        sentinelArrived.complete(event);
      }
    });
    api.eventsController.add(
      const BridgeSsePermissionReplied(
        requestID: "before",
        sessionID: "busy",
        displaySessionId: "busy",
        reply: "reject",
      ),
    );
    await _waitUntil(() => events.isNotEmpty);
    plugin.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);
    plugin.interruptActiveWorkHandler = (_) async {
      api.eventsController
        ..add(
          const BridgeSsePermissionAsked(
            requestID: "ask",
            sessionID: "busy",
            displaySessionId: "busy",
            tool: "shell",
            description: "must remain fenced",
            allowAlways: true,
          ),
        )
        ..add(
          const BridgeSsePermissionReplied(
            requestID: "permission",
            sessionID: "busy",
            displaySessionId: "busy",
            reply: "reject",
          ),
        )
        ..add(
          const BridgeSseQuestionReplied(
            requestID: "question-replied",
            sessionID: "busy",
            displaySessionId: "busy",
          ),
        )
        ..add(
          const BridgeSseTerminalHandoff(
            event: BridgeSsePermissionReplied(
              requestID: "spoofed",
              sessionID: "busy",
              displaySessionId: "busy",
              reply: "reject",
            ),
          ),
        );
      scheduleMicrotask(
        () => api.eventsController.add(
          const BridgeSseQuestionRejected(
            requestID: "question-rejected",
            sessionID: "busy",
            displaySessionId: "busy",
          ),
        ),
      );
      plugin.workStates.add(PluginWorkState.idle);
      return const <String>{};
    };

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.force);
    final sentinel = await sentinelArrived.future.timeout(const Duration(seconds: 1));
    expect(
      (sentinel.event as BridgeSseTerminalHandoff).event,
      isA<BridgeSseProjectUpdated>(),
    );
    expect(
      events.indexOf(sentinel),
      greaterThan(events.lastIndexWhere((event) => event.event is BridgeSseQuestionRejected)),
    );
    api.eventsController.add(
      const BridgeSsePermissionReplied(
        requestID: "after",
        sessionID: "busy",
        displaySessionId: "busy",
        reply: "reject",
      ),
    );
    await _waitUntil(
      () => events.where((event) => event.event is BridgeSsePermissionReplied).length == 3,
    );
    sentinel.terminalHandoffConsumed!.complete();
    expect(await stopping, isA<PluginRuntimeCommandApplied>());

    expect(
      events.where((event) => event.event is BridgeSsePermissionReplied).map((event) => event.allowDuringStop),
      [false, true, false],
    );
    expect(
      events.singleWhere((event) => event.event is BridgeSsePermissionAsked).allowDuringStop,
      isFalse,
    );
    expect(
      events.singleWhere((event) => event.event is BridgeSseQuestionReplied).allowDuringStop,
      isTrue,
    );
    expect(
      events.singleWhere((event) => event.event is BridgeSseQuestionRejected).allowDuringStop,
      isTrue,
    );
    expect(
      events
          .singleWhere(
            (event) =>
                event.event is BridgeSseTerminalHandoff &&
                (event.event as BridgeSseTerminalHandoff).event is BridgeSsePermissionReplied,
          )
          .allowDuringStop,
      isFalse,
    );
    expect(sentinel.allowDuringStop, isTrue);

    await eventSubscription.cancel();
  });

  test("a force restart waits for terminal handoff consumption before starting its successor", () async {
    late _FakePlugin firstPlugin;
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (generation) {
        final plugin = _FakePlugin(api: _FakeApi());
        if (generation == 1) firstPlugin = plugin;
        return plugin;
      },
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    firstPlugin.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);
    firstPlugin.interruptActiveWorkHandler = (_) async {
      firstPlugin.workStates.add(PluginWorkState.idle);
      return {"busy"};
    };
    final terminalHandoff = Completer<SourcedPluginRuntimeEvent>();
    final subscription = runtime.backendEvents.listen((event) {
      if (event.terminalHandoffConsumed != null && !terminalHandoff.isCompleted) {
        terminalHandoff.complete(event);
      }
    });

    final restarting = runtime.restart(pluginId: "one", intent: PluginStopIntent.force);
    final handoff = await terminalHandoff.future.timeout(const Duration(seconds: 1));

    expect(factory.startCount, 1);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.restarting);
    handoff.terminalHandoffConsumed!.complete();
    expect(await restarting, isA<PluginRuntimeCommandApplied>());
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);

    await subscription.cancel();
  });

  test("prepare disable fences starts until rollback restores access", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    final result = await runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.safe);

    expect(result, isA<PluginRuntimeCommandCurrent>());
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.stopping);
    await expectLater(
      runtime.use(pluginId: "one", operation: _TestOperation.duringStop, body: (_) async {}),
      throwsA(isA<PluginOperationException>()),
    );

    runtime.rollbackDisable(pluginId: "one");

    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
    expect(await runtime.start(pluginId: "one"), isA<PluginRuntimeCommandApplied>());
  });

  test("prepare disable restores access after a safe conflict", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.start(pluginId: "one");
    factory.plugins.single.workStates.add(PluginWorkState.busy);
    await _waitUntil(() => runtime.snapshot.single.workState == PluginWorkState.busy);

    final result = await runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.safe);

    expect(result, isA<PluginRuntimeCommandConflict>());
    expect(result.snapshot.state, PluginRuntimeState.active);
    expect(result.snapshot.accessGate != PluginRuntimeAccessGate.disabled, isTrue);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
    expect(
      await runtime.use(pluginId: "one", operation: _TestOperation.read, body: (_) async => "available"),
      "available",
    );
  });

  test("commit disable makes the retained dormant slot ineligible", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    expect(
      await runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandCurrent>(),
    );

    runtime.commitDisable(pluginId: "one");

    expect(runtime.snapshot.single.state, PluginRuntimeState.disabled);
    expect(runtime.snapshot.single.accessGate != PluginRuntimeAccessGate.disabled, isFalse);
    expect(runtime.snapshot.single.startAllowed, isFalse);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
    expect(await runtime.start(pluginId: "one"), isA<PluginRuntimeCommandConflict>());
  });

  test("invalid disable commit settles the slot fail-closed", () async {
    final runtime = _runtime(factory: _FakeGenerationFactory(startGate: Future<void>.value()));

    expect(() => runtime.commitDisable(pluginId: "one"), throwsStateError);

    expect(runtime.snapshot.single.accessGate, PluginRuntimeAccessGate.disabled);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
    await runtime.dispose().timeout(const Duration(seconds: 1));
  });

  test("invalid disable rollback settles the slot enabled", () async {
    final runtime = _runtime(factory: _FakeGenerationFactory(startGate: Future<void>.value()));

    expect(() => runtime.rollbackDisable(pluginId: "one"), throwsStateError);

    expect(runtime.snapshot.single.accessGate, PluginRuntimeAccessGate.enabled);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
    await runtime.dispose().timeout(const Duration(seconds: 1));
  });

  test("access refresh cannot overwrite a prepared disable gate", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.safe);

    runtime.applyAccess(
      entries: const [
        PluginRuntimeAccess(
          pluginId: "one",
          gate: PluginRuntimeAccessGate.disabled,
          startAllowed: false,
        ),
      ],
    );

    expect(runtime.snapshot.single.accessGate, PluginRuntimeAccessGate.draining);
    expect(runtime.snapshot.single.startAllowed, isTrue);
    runtime.commitDisable(pluginId: "one");
    expect(runtime.snapshot.single.accessGate, PluginRuntimeAccessGate.disabled);
  });

  test("runtime disposal waits for a prepared disable decision", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    await runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.safe);
    var disposeCompleted = false;

    final disposing = runtime.dispose().whenComplete(() => disposeCompleted = true);
    await Future<void>.delayed(Duration.zero);

    expect(disposeCompleted, isFalse);

    runtime.rollbackDisable(pluginId: "one");
    await disposing;
  });

  test("authentication failure fences and blocks its generation", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await expectLater(
      runtime.use<void>(
        pluginId: "one",
        operation: _TestOperation.use,
        body: (_) => throw const PluginAuthenticationRequiredException(
          "test",
          actionHint: "Authenticate locally.",
        ),
      ),
      throwsA(isA<PluginAuthenticationRequiredException>()),
    );
    await _waitUntil(
      () => runtime.snapshot.single.state == PluginRuntimeState.blocked && factory.plugins.single.shutdownCount == 1,
    );

    expect(runtime.snapshot.single.setup, isA<PluginSetupAuthenticationRequired>());
    expect(runtime.activePluginIds, isEmpty);
    expect(factory.plugins.single.shutdownCount, 1);
  });

  test("authentication loss cancels operation streams before waiting for leases", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final failingSource = StreamController<int>();
    final silentSource = StreamController<int>();
    final failingSourceCancelled = Completer<void>();
    final silentSourceCancelled = Completer<void>();
    final failingDone = Completer<void>();
    final silentDone = Completer<void>();
    final errors = <Object>[];
    failingSource.onCancel = failingSourceCancelled.complete;
    silentSource.onCancel = silentSourceCancelled.complete;
    runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) => failingSource.stream,
        )
        .listen(
          (_) {},
          onError: errors.add,
          onDone: failingDone.complete,
        );
    runtime
        .useStream(
          pluginId: "one",
          operation: _TestOperation.stream,
          body: (_, _) => silentSource.stream,
        )
        .listen((_) {}, onDone: silentDone.complete);
    await _waitUntil(
      () => runtime.snapshot.single.leaseCount == 2 && failingSource.hasListener && silentSource.hasListener,
    );

    failingSource.addError(
      const PluginAuthenticationRequiredException(
        "stream",
        actionHint: "Authenticate locally.",
      ),
    );

    await Future.wait([
      failingSourceCancelled.future,
      silentSourceCancelled.future,
      failingDone.future,
      silentDone.future,
    ]).timeout(const Duration(seconds: 1));
    await _waitUntil(
      () => runtime.snapshot.single.state == PluginRuntimeState.blocked && factory.plugins.single.shutdownCount == 1,
    );
    expect(errors, [isA<PluginAuthenticationRequiredException>()]);
    expect(runtime.snapshot.single.leaseCount, 0);
    await failingSource.close();
    await silentSource.close();
  });

  test("a command-owned stop rejects force takeover until teardown finishes", () async {
    final shutdownGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (generation) => _FakePlugin(
        api: _FakeApi(),
        shutdownGate: generation == 1 ? shutdownGate.future : null,
      ),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(() async {
      if (!shutdownGate.isCompleted) shutdownGate.complete();
      await runtime.dispose();
    });
    await runtime.startEager(pluginIds: const ["one"]);
    final originalPlugin = factory.plugins.single;

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    final takeover = await runtime.restart(pluginId: "one", intent: PluginStopIntent.force);

    expect(takeover, isA<PluginRuntimeCommandConflict>());
    expect(factory.startCount, 1);
    shutdownGate.complete();
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(originalPlugin.shutdownInvocationCount, 1);
    expect(runtime.snapshot.single.generation, 1);
    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("disable conflict preserves another command's transition ownership", () async {
    final shutdownGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(api: _FakeApi(), shutdownGate: shutdownGate.future),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(() async {
      if (!shutdownGate.isCompleted) shutdownGate.complete();
      await runtime.dispose();
    });
    await runtime.startEager(pluginIds: const ["one"]);

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    await _waitUntil(() => factory.plugins.single.shutdownInvocationCount == 1);
    final conflict = await runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.force);

    expect(conflict, isA<PluginRuntimeCommandConflict>());
    expect(runtime.snapshot.single.accessGate, PluginRuntimeAccessGate.enabled);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.stopping);

    shutdownGate.complete();
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("runtime disposal waits for command-owned generation teardown", () async {
    final shutdownGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(api: _FakeApi(), shutdownGate: shutdownGate.future),
    );
    final runtime = _runtime(factory: factory);
    await runtime.startEager(pluginIds: const ["one"]);

    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.safe);
    await _waitUntil(() => factory.plugins.single.shutdownInvocationCount == 1);
    var disposeCompleted = false;
    final disposing = runtime.dispose().whenComplete(() => disposeCompleted = true);
    await Future<void>.delayed(Duration.zero);

    expect(disposeCompleted, isFalse);

    shutdownGate.complete();
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    await disposing;
  });

  test("a force stop drains a pre-fence operation before retiring the generation", () async {
    final operationGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final operation = runtime.use(
      pluginId: "one",
      operation: _TestOperation.forceFenced,
      body: (_) => operationGate.future,
    );
    await _waitUntil(() => runtime.snapshot.single.leaseCount == 1);

    var stopCompleted = false;
    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.force).whenComplete(() {
      stopCompleted = true;
    });
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);
    await Future<void>.delayed(Duration.zero);

    expect(stopCompleted, isFalse);
    operationGate.complete();

    await expectLater(
      operation,
      throwsA(
        isA<PluginOperationException>().having(
          (error) => error.operation,
          "operation",
          "forceFenced",
        ),
      ),
    );
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(runtime.snapshot.single.state, PluginRuntimeState.dormant);
  });

  test("a force stop waits for a generation's durable commit", () async {
    final commitStarted = Completer<void>();
    final commitGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    final operation = runtime.useAndCommit<String, String>(
      pluginId: "one",
      operation: _TestOperation.durableCommit,
      prepare: (_) async => "prepared",
      commit: (prepared, generation) async {
        expect(generation, 1);
        commitStarted.complete();
        await commitGate.future;
        return prepared;
      },
    );
    await commitStarted.future;

    var stopCompleted = false;
    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.force).whenComplete(() {
      stopCompleted = true;
    });
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);
    await Future<void>.delayed(Duration.zero);

    expect(stopCompleted, isFalse);
    expect(factory.plugins.single.shutdownInvocationCount, 0);

    commitGate.complete();
    expect(await operation, "prepared");
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
    expect(factory.plugins.single.shutdownInvocationCount, 1);
  });

  test("a force stop waits for an explicit current-generation commit", () async {
    final commitStarted = Completer<void>();
    final commitGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    final operation = runtime.commitCurrentGeneration(
      pluginId: "one",
      generation: 1,
      operation: _TestOperation.durableCommit,
      commit: () async {
        commitStarted.complete();
        await commitGate.future;
        return "committed";
      },
    );
    await commitStarted.future;
    var stopCompleted = false;
    final stopping = runtime.stop(pluginId: "one", intent: PluginStopIntent.force).whenComplete(() {
      stopCompleted = true;
    });
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);
    await Future<void>.delayed(Duration.zero);

    expect(stopCompleted, isFalse);

    commitGate.complete();
    expect(await operation, "committed");
    expect(await stopping, isA<PluginRuntimeCommandApplied>());
  });

  test("authentication loss cannot unsettle a prepared disable", () async {
    final commitStarted = Completer<void>();
    final commitGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final operation = runtime.useAndCommit<void, void>(
      pluginId: "one",
      operation: _TestOperation.durableCommit,
      prepare: (_) async {},
      commit: (_, _) async {
        commitStarted.complete();
        await commitGate.future;
      },
    );
    await commitStarted.future;

    final preparing = runtime.prepareDisable(pluginId: "one", intent: PluginStopIntent.force);
    await _waitUntil(() => runtime.snapshot.single.accessGate == PluginRuntimeAccessGate.draining);
    factory.api.eventsController.addError(
      const PluginAuthenticationRequiredException("test", actionHint: "Authenticate locally."),
    );
    await _waitUntil(() => runtime.snapshot.single.setup is PluginSetupAuthenticationRequired);
    commitGate.complete();
    await operation;

    expect(await preparing, isA<PluginRuntimeCommandApplied>());
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.stopping);
    runtime.rollbackDisable(pluginId: "one");
    expect(runtime.snapshot.single.accessGate, PluginRuntimeAccessGate.enabled);
    expect(runtime.snapshot.single.state, PluginRuntimeState.blocked);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("a terminal failure waits for a generation's durable commit", () async {
    final commitStarted = Completer<void>();
    final commitGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final plugin = factory.plugins.single;

    final operation = runtime.useAndCommit<String, String>(
      pluginId: "one",
      operation: _TestOperation.durableCommit,
      prepare: (_) async => "prepared",
      commit: (prepared, generation) async {
        expect(generation, 1);
        commitStarted.complete();
        await commitGate.future;
        return prepared;
      },
    );
    await commitStarted.future;

    plugin.statuses.add(const PluginFailed(reason: "terminal", cause: null));
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);
    expect(plugin.shutdownInvocationCount, 0);

    commitGate.complete();
    expect(await operation, "prepared");
    await _waitUntil(
      () =>
          runtime.snapshot.single.state == PluginRuntimeState.failed &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );
    expect(plugin.shutdownInvocationCount, 1);
  });

  test("restart keeps its transition serialized through the successor start", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    final result = await runtime.restart(pluginId: "one", intent: PluginStopIntent.safe);

    expect(result, isA<PluginRuntimeCommandApplied>());
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("a force restart aborts an in-flight start before starting its successor", () async {
    final startGate = Completer<void>();
    final factory = _FakeGenerationFactory(startGate: startGate.future);
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    final initialStart = runtime.startEager(pluginIds: const ["one"]);
    await _waitUntil(() => factory.startCount == 1);

    final restarting = runtime.restart(pluginId: "one", intent: PluginStopIntent.force);
    startGate.complete();

    await expectLater(initialStart, throwsA(isA<PluginStartAbortedException>()));
    expect(await restarting, isA<PluginRuntimeCommandApplied>());
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);
  });

  test("a force restart recovers a generation stuck in PluginStopping", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final stoppingPlugin = factory.plugins.single;

    stoppingPlugin.statuses.add(const PluginStopping());
    await _waitUntil(() => runtime.snapshot.single.transition == PluginRuntimeTransition.stopping);

    expect(
      await runtime.restart(pluginId: "one", intent: PluginStopIntent.safe),
      isA<PluginRuntimeCommandConflict>(),
    );
    expect(
      await runtime.restart(pluginId: "one", intent: PluginStopIntent.force),
      isA<PluginRuntimeCommandApplied>(),
    );
    expect(stoppingPlugin.shutdownCount, 1);
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);
    expect(runtime.snapshot.single.transition, PluginRuntimeTransition.none);
  });

  test("a terminal plugin failure fences its generation and allows a later retry", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);
    final failedPlugin = factory.plugins.single;

    failedPlugin.statuses.add(const PluginFailed(reason: "terminal", cause: null));
    await _waitUntil(
      () =>
          runtime.snapshot.single.state == PluginRuntimeState.failed &&
          runtime.snapshot.single.transition == PluginRuntimeTransition.none,
    );

    final result = await runtime.use(
      pluginId: "one",
      operation: _TestOperation.retry,
      body: (_) async => "retried",
    );

    expect(result, "retried");
    expect(factory.startCount, 2);
    expect(runtime.snapshot.single.generation, 2);
    expect(failedPlugin.shutdownCount, 1);
  });

  test("shared factory failures propagate instead of degrading one plugin", () async {
    const error = BridgeRuntimeServerException("bridge ownership failed");
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      startError: error,
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await expectLater(
      runtime.startEager(pluginIds: const ["one"]),
      throwsA(same(error)),
    );
  });

  test("descriptor-local factory failures leave the plugin failed without aborting eager startup", () async {
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      startError: const PluginGenerationStartFailedException(
        pluginId: "one",
        cause: "descriptor failed",
      ),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await runtime.startEager(pluginIds: const ["one"]);

    expect(runtime.snapshot.single.state, PluginRuntimeState.failed);
    expect(runtime.activePluginIds, isEmpty);
  });

  test("an invalid returned plugin is shut down and never routed", () async {
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(api: _FakeApi(id: "wrong")),
    );
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);

    await runtime.startEager(pluginIds: const ["one"]);

    expect(runtime.activePluginIds, isEmpty);
    expect(runtime.snapshot.single.state, PluginRuntimeState.failed);
    expect(factory.plugins.single.shutdownCount, 1);
  });

  test("shutdown cleans up a plugin that returns after plugin shutdown begins", () async {
    final startGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: startGate.future,
      honorAbort: false,
    );
    final runtime = _runtime(factory: factory);
    final starting = runtime.startEager(pluginIds: const ["one"]);
    await _waitUntil(() => factory.startCount == 1);

    runtime.beginShutdown();
    final shuttingDownPlugins = runtime.shutdownStartedPlugins();
    startGate.complete();

    await expectLater(starting, throwsA(isA<PluginStartAbortedException>()));
    await shuttingDownPlugins;
    expect(factory.plugins.single.shutdownCount, 1);
    await runtime.dispose();
  });

  test("plugin shutdown owns API disposal before runtime lifecycle cleanup", () async {
    final shutdownGate = Completer<void>();
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(
        api: _FakeApi(),
        shutdownGate: shutdownGate.future,
      ),
    );
    final runtime = _runtime(factory: factory);
    await runtime.startEager(pluginIds: const ["one"]);

    runtime.beginShutdown();
    final shuttingDownPlugins = runtime.shutdownStartedPlugins();
    await _waitUntil(() => factory.plugins.single.shutdownCount == 1);

    expect(factory.api.disposeCount, 0, reason: "core must not bypass the plugin's teardown ordering");
    shutdownGate.complete();
    await shuttingDownPlugins;
    expect(factory.api.disposeCount, 1);
    await runtime.dispose();
  });

  test("event closure during plugin shutdown does not hide its failure", () async {
    final shutdownError = StateError("runtime shutdown failed");
    final factory = _FakeGenerationFactory(
      startGate: Future<void>.value(),
      pluginFactory: (_) => _FakePlugin(
        api: _FakeApi(closeEventsOnDispose: true),
        shutdownError: shutdownError,
      ),
    );
    final runtime = _runtime(factory: factory);
    await runtime.startEager(pluginIds: const ["one"]);

    runtime.beginShutdown();
    await expectLater(runtime.shutdownStartedPlugins(), throwsA(same(shutdownError)));
    expect(runtime.snapshot.single.state, PluginRuntimeState.active);

    await expectLater(runtime.dispose(), throwsA(same(shutdownError)));
  });

  test("backend events carry plugin and generation attribution", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    final eventFuture = runtime.backendEvents.first;
    factory.api.eventsController.add(const BridgeSseProjectUpdated());
    final sourced = await eventFuture;

    expect(sourced.pluginId, "one");
    expect(sourced.generation, 1);
    expect(sourced.event, isA<BridgeSseProjectUpdated>());
  });

  test("backend events emitted before the bridge listener attaches are replayed", () async {
    final factory = _FakeGenerationFactory(startGate: Future<void>.value());
    final runtime = _runtime(factory: factory);
    addTearDown(runtime.dispose);
    await runtime.startEager(pluginIds: const ["one"]);

    factory.api.eventsController.add(const BridgeSseProjectUpdated());
    final sourced = await runtime.backendEvents.first;

    expect(sourced.pluginId, "one");
    expect(sourced.generation, 1);
    expect(sourced.event, isA<BridgeSseProjectUpdated>());
  });
}

enum _TestOperation() {
  use,
  capture,
  read,
  watch,
  activeRead,
  directFence,
  first,
  second,
  stream,
  duringStop,
  forceFenced,
  durableCommit,
  retry,
}

PluginRuntime _runtime({
  required _FakeGenerationFactory factory,
  BridgePluginDescriptor descriptor = const _FakeDescriptor(),
  Duration shutdownBudget = const Duration(seconds: 1),
}) {
  final runtime = PluginRuntime(
    registrations: [
      PluginRuntimeRegistration(
        descriptor: descriptor,
        config: const PluginConfig(values: {}),
        stateDirectory: ".",
        store: _testHostJsonStore,
      ),
    ],
    generationFactory: factory,
    setupProcesses: const _UnusedHostProcessService(),
    environment: const {},
    clock: const ServerClock(),
    shutdownBudget: shutdownBudget,
  );
  runtime.applyAccess(
    entries: const [
      PluginRuntimeAccess(
        pluginId: "one",
        gate: PluginRuntimeAccessGate.enabled,
        startAllowed: true,
      ),
    ],
  );
  return runtime;
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError("condition did not become true");
}

class _FakeGenerationFactory({
  required final Future<void> startGate,
  final _FakePlugin Function(int generation)? pluginFactory,
  final Object? startError,
  final bool honorAbort = true,
}) implements PluginGenerationFactory {
  final List<_FakePlugin> plugins = <_FakePlugin>[];
  int startCount = 0;

  _FakeApi get api => plugins.last.api;

  @override
  Future<void> enforceBridgeOwnership() async {}

  @override
  Stream<PluginGenerationStartEvent> start({
    required PluginRuntimeRegistration registration,
    required StartAbortSignal startAborted,
  }) async* {
    startCount++;
    await startGate;
    if (startError case final error?) throw error;
    if (honorAbort && startAborted.isAborted) throw const PluginStartAbortedException();
    final plugin = pluginFactory?.call(startCount) ?? _FakePlugin(api: _FakeApi());
    plugins.add(plugin);
    yield PluginGenerationStarted(plugin: plugin);
  }
}

class const _FakeDescriptor({
  final Future<PluginSetupStatus> Function()? inspect,
  final Stream<RuntimeProvisionProgress> Function(StartAbortSignal startAborted)? install,
}) extends BridgePluginDescriptor {
  @override
  String get id => "one";

  @override
  String get displayName => "One";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.native;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.project;

  @override
  List<PluginOption> get options => const [];

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) {
    return inspect?.call() ?? Future.value(const PluginSetupReady());
  }

  @override
  Stream<RuntimeProvisionProgress> installRuntime({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
  }) {
    final handler = install;
    if (handler == null) {
      return super.installRuntime(
        config: config,
        processes: processes,
        environment: environment,
        stateDirectory: stateDirectory,
        startAborted: startAborted,
      );
    }
    return handler(startAborted);
  }

  @override
  Future<BridgePlugin> start(PluginHost host) => throw UnsupportedError("fake factory owns construction");
}

class const _AuthenticationDescriptor({
  required final Stream<PluginAuthenticationEvent> Function({required StartAbortSignal aborted}) _authenticate,
  required final PluginAuthenticationOperationKind _kind,
  required final void Function({required HostJsonStore store}) _recordStore,
}) extends _FakeDescriptor implements InteractivePluginAuthenticationDescriptor {
  @override
  PluginAuthenticationOperation authenticate({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required HostJsonStore store,
    required StartAbortSignal aborted,
  }) {
    _recordStore(store: store);
    return PluginAuthenticationOperation(
      events: _authenticate(aborted: aborted),
      kind: _kind,
    );
  }
}

class const _UnusedHostJsonStore() implements HostJsonStore {
  @override
  Future<void> delete({required String name}) => throw UnsupportedError("unused");

  @override
  Future<void> quarantine({required String name, required String quarantinedName}) => throw UnsupportedError("unused");

  @override
  Future<String?> read({required String name}) => throw UnsupportedError("unused");

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) => throw UnsupportedError("unused");

  @override
  Future<void> write({required String name, required String contents}) => throw UnsupportedError("unused");
}

class _FakePlugin({
  @override required final _FakeApi api,
  final Future<void>? shutdownGate,
  final Object? shutdownError,
}) implements BridgePlugin {
  final BehaviorSubject<PluginStatus> statuses = BehaviorSubject.seeded(const PluginReady());
  final BehaviorSubject<PluginWorkState> workStates = BehaviorSubject.seeded(PluginWorkState.idle);
  Future<void>? _shutdownFuture;
  int shutdownInvocationCount = 0;
  int shutdownCount = 0;
  int interruptActiveWorkCount = 0;
  Future<Set<String>> Function(Duration budget)? interruptActiveWorkHandler;

  @override
  PluginStatus get currentStatus => statuses.value;

  @override
  Stream<PluginStatus> get status => statuses.stream;

  @override
  PluginWorkState get currentWorkState => workStates.value;

  @override
  Stream<PluginWorkState> get workState => workStates.stream;

  @override
  PluginDiagnostics describe() => const PluginDiagnostics(pluginId: "one", endpoint: null, details: {});

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) async {
    interruptActiveWorkCount++;
    return await interruptActiveWorkHandler?.call(budget) ?? const {};
  }

  @override
  Future<void> shutdown({required Duration? budget}) {
    shutdownInvocationCount++;
    return _shutdownFuture ??= _shutdown();
  }

  Future<void> _shutdown() async {
    shutdownCount++;
    await shutdownGate;
    await api.dispose();
    if (shutdownError case final error?) throw error;
    if (!api.eventsController.isClosed) await api.eventsController.close();
    if (!statuses.isClosed) await statuses.close();
    if (!workStates.isClosed) await workStates.close();
  }
}

class _FakeApi({
  @override final String id = "one",
  final bool closeEventsOnDispose = false,
  final List<PluginProjectActivitySummary> activeSessionsSummary = const [],
}) extends NativeProjectsPluginApi {
  final StreamController<BridgeSseEvent> eventsController = StreamController.broadcast();
  int disposeCount = 0;
  int getActiveSessionsSummaryCount = 0;

  @override
  Stream<BridgeSseEvent> get events => eventsController.stream;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    getActiveSessionsSummaryCount++;
    return activeSessionsSummary;
  }

  Future<void> dispose() async {
    disposeCount++;
    if (closeEventsOnDispose && !eventsController.isClosed) await eventsController.close();
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _UnusedHostProcessService() implements HostProcessService {
  @override
  Future<ProcessIdentity?> inspect({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SignalResult> signalForce({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SignalResult> signalGraceful({required int pid}) => throw UnsupportedError("unused");

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) => throw UnsupportedError("unused");
}

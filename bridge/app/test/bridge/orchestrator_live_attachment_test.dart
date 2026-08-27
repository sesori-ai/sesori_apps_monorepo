import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_bridge/src/models/bridge_config.dart";
import "package:sesori_bridge/src/orchestrator.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/plugin_runtime_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_chat_history.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

const _pluginId = "one";
const _backendSessionId = "backend-ses";
const _sessionId = "ses_live";

void main() {
  test("an image part is stored before its live event and the local stream keeps the inline shape", () async {
    final harness = await _LiveAttachmentHarness.create();
    addTearDown(harness.close);
    final imageBytes = Uint8List.fromList(List<int>.generate(32, (index) => index));

    final delivered = harness.nextMessagePartUpdated();
    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(
          id: "p_image",
          attachment: PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(imageBytes),
            filename: "shot.png",
          ),
        ),
      ),
    );
    final event = await delivered;

    expect(
      (event.part as MessagePartFile).attachment,
      isA<MessageAttachmentInlineImage>().having((image) => image.base64, "base64", base64Encode(imageBytes)),
      reason: "the local debug stream has no capability surface, so it keeps the released shape",
    );
    final rows = await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId);
    expect(
      rows.single.partJson,
      contains("stored_file"),
      reason: "the spill write must have landed before the event reached the wire",
    );
    expect(rows.single.partJson, isNot(contains(base64Encode(imageBytes))));
  });

  test("parts are persisted in plugin emission order even when one is awaited", () async {
    final harness = await _LiveAttachmentHarness.create();
    addTearDown(harness.close);

    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(
          id: "p_image",
          attachment: PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1, 2, 3])),
            filename: "shot.png",
          ),
        ),
      ),
    );
    final lastDelivered = harness.nextMessagePartUpdated(partId: "p_text");
    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(id: "p_text", text: "after the image"),
      ),
    );
    await lastDelivered;

    await _waitFor(
      () async => (await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId)).length == 2,
      reason: "both parts stored",
    );
    final rows = await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId);
    expect(
      (rows..sort((left, right) => left.orderIndex.compareTo(right.orderIndex))).map((row) => row.partId),
      const ["p_image", "p_text"],
    );
  });

  test("an invisible part is stored without reaching the wire", () async {
    final harness = await _LiveAttachmentHarness.create();
    addTearDown(harness.close);

    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(id: "p_snapshot", type: PluginMessagePartType.snapshot),
      ),
    );
    final delivered = harness.nextMessagePartUpdated(partId: "p_text");
    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(id: "p_text", text: "visible"),
      ),
    );
    await delivered;

    await _waitFor(
      () async => (await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId)).length == 2,
      reason: "both parts stored",
    );
    final rows = await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId);
    expect(rows.map((row) => row.partId), containsAll(const ["p_snapshot", "p_text"]));
    expect(
      harness.deliveredPartIds,
      isNot(contains("p_snapshot")),
      reason: "invisible parts are stored for history but never rendered live",
    );
  });

  test("an unknown part is dropped without interrupting later plugin events", () async {
    final harness = await _LiveAttachmentHarness.create();
    addTearDown(harness.close);

    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(id: "p_unknown", type: PluginMessagePartType.unknown),
      ),
    );
    final delivered = harness.nextMessagePartUpdated(partId: "p_text");
    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(id: "p_text", text: "visible"),
      ),
    );
    await delivered;

    await _waitFor(
      () async => (await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId)).isNotEmpty,
      reason: "the later visible part to be stored",
    );
    final rows = await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId);
    expect(rows.map((row) => row.partId), equals(["p_text"]));
    expect(harness.deliveredPartIds, isNot(contains("p_unknown")));
  });

  test("a part removal stays ordered after an immediately preceding update", () async {
    final harness = await _LiveAttachmentHarness.create();
    addTearDown(harness.close);

    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(
          id: "p_removed",
          attachment: PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1, 2, 3])),
            filename: "shot.png",
          ),
        ),
      ),
    );
    harness.plugin.emitEvent(
      const BridgeSseMessagePartRemoved(
        sessionID: _backendSessionId,
        messageID: "m1",
        partID: "p_removed",
      ),
    );
    final delivered = harness.nextMessagePartUpdated(partId: "p_after");
    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(id: "p_after", text: "after removal"),
      ),
    );
    await delivered;

    await _waitFor(
      () async => (await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId)).isNotEmpty,
      reason: "the part after the removal to be stored",
    );
    final rows = await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId);
    expect(rows.map((row) => row.partId), equals(["p_after"]));
  });

  test("a message removal stays ordered after an immediately preceding part update", () async {
    final harness = await _LiveAttachmentHarness.create();
    addTearDown(harness.close);

    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(
          id: "p_removed",
          attachment: PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1, 2, 3])),
            filename: "shot.png",
          ),
        ),
      ),
    );
    harness.plugin.emitEvent(
      const BridgeSseMessageRemoved(sessionID: _backendSessionId, messageID: "m1"),
    );
    final delivered = harness.nextMessagePartUpdated(partId: "p_after");
    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(id: "p_after", text: "after removal", messageId: "m2"),
      ),
    );
    await delivered;

    await _waitFor(
      () async => (await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId)).isNotEmpty,
      reason: "the part after the message removal to be stored",
    );
    final rows = await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId);
    expect(rows.map((row) => row.partId), equals(["p_after"]));
  });

  test("a stale generation stops the part before capture and delivery", () async {
    final harness = await _LiveAttachmentHarness.create();
    addTearDown(harness.close);
    final pluginRuntime = runtimeForLifecycleService(service: harness.lifecycleService) as TestPluginRuntime;
    pluginRuntime.generationCurrent = false;

    harness.plugin.emitEvent(
      BridgeSseMessagePartUpdated(
        part: _pluginPart(
          id: "p_stale",
          attachment: PluginMessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1, 2, 3])),
            filename: "shot.png",
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(await harness.chatHistory.database.chatHistoryDao.getParts(sessionId: _sessionId), isEmpty);
    expect(harness.deliveredPartIds, isEmpty);
  });
}

Future<void> _waitFor(Future<bool> Function() condition, {required String reason}) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail("Timed out waiting for $reason");
}

PluginMessagePart _pluginPart({
  required String id,
  String? text,
  String messageId = "m1",
  PluginMessagePartType type = PluginMessagePartType.text,
  PluginMessageAttachment? attachment,
}) => attachment != null
    ? PluginMessagePart.file(
        id: id,
        sessionID: _backendSessionId,
        messageID: messageId,
        attachment: attachment,
      )
    : switch (type) {
        PluginMessagePartType.text => PluginMessagePart.text(
          id: id,
          sessionID: _backendSessionId,
          messageID: messageId,
          text: text!,
        ),
        PluginMessagePartType.snapshot => PluginMessagePart.snapshot(
          id: id,
          sessionID: _backendSessionId,
          messageID: messageId,
        ),
        PluginMessagePartType.unknown => PluginMessagePart.unknown(
          id: id,
          sessionID: _backendSessionId,
          messageID: messageId,
        ),
        _ => throw StateError("Unsupported test part type: $type"),
      };

class _LiveAttachmentHarness({
  required final FakeBridgePlugin plugin,
  required final PluginLifecycleService lifecycleService,
  required final OrchestratorComposition composition,
  required final BridgeRuntime runtime,
  required final TestChatHistory chatHistory,
  required final http.Client httpClient,
  required final TestRelayServer relayServer,
  required final Future<void> stopped,
  required final StreamSubscription<SesoriSseEvent> _subscription,
  required final List<String> deliveredPartIds,
}) {
  static Future<_LiveAttachmentHarness> create() async {
    final plugin = _SourcedPlugin(_pluginId);
    final lifecycleService = await createPluginLifecycleService(plugins: [plugin]);
    final database = createTestDatabase();
    final chatHistory = createTestChatHistory();
    final httpClient = http.Client();
    final failureReporter = FakeFailureReporter();
    final relayServer = await TestRelayServer.start();
    final relayUrl = "ws://127.0.0.1:${relayServer.port}";
    final composition = Orchestrator(
      config: BridgeConfig(
        relayURL: relayUrl,
        authBackendURL: "https://api.sesori.test",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: RelayClient(
        relayURL: relayUrl,
        accessTokenProvider: FakeAccessTokenProvider(),
        bridgeIdProvider: FakeBridgeIdProvider(),
      ),
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
      clock: const ServerClock(),
      database: database,
      chatHistoryDatabase: chatHistory.database,
      attachmentSpillStorage: chatHistory.spillStorage,
      archivedSessionStorage: chatHistory.archivedStorage,
      httpClient: httpClient,
      processRunner: NoopProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: FakeTokenRefresher(token: "token"),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      projectGlossarySecretStorage: const FakeProjectGlossarySecretStorage(),
      failureReporter: failureReporter,
      restartService: buildTestRestartService(),
      filesystemAccessOk: true,
      statusNotifier: null,
      reconnectBackoff: ReconnectBackoffPolicy.standard,
    ).create();
    final runtime = BridgeRuntime(
      database: database,
      chatHistoryDatabase: chatHistory.database,
      failureReporter: failureReporter,
      composition: composition,
    );
    await _insertRootSession(database: database);

    final running = await startTestOrchestratorSession(session: composition.session);
    await relayServer.nextClient();
    await activateTestPlugin(service: lifecycleService, pluginId: _pluginId);
    final deliveredPartIds = <String>[];
    // Cancelled by close(), which every test registers as its teardown.
    // ignore: cancel_subscriptions
    final subscription = composition.session.localWireEvents.listen((event) {
      if (event is SesoriMessagePartUpdated) deliveredPartIds.add(event.part.id);
    });
    final harness = _LiveAttachmentHarness(
      plugin: plugin,
      lifecycleService: lifecycleService,
      composition: composition,
      runtime: runtime,
      chatHistory: chatHistory,
      httpClient: httpClient,
      relayServer: relayServer,
      stopped: running.stopped,
      subscription: subscription,
      deliveredPartIds: deliveredPartIds,
    );
    await harness._awaitEventSubscription();
    return harness;
  }

  /// Emits a harmless event until it comes back, proving the plugin event
  /// subscription is live before the test emits the event it asserts on.
  Future<void> _awaitEventSubscription() async {
    final ready = Completer<void>();
    final subscription = composition.session.localWireEvents.where((event) => event is SesoriVcsBranchUpdated).listen((
      _,
    ) {
      if (!ready.isCompleted) ready.complete();
    });
    try {
      for (var attempt = 0; attempt < 200 && !ready.isCompleted; attempt++) {
        plugin.emitEvent(const BridgeSseVcsBranchUpdated());
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      if (!ready.isCompleted) throw TimeoutException("Plugin event subscription did not start");
    } finally {
      await subscription.cancel();
    }
  }

  Future<SesoriMessagePartUpdated> nextMessagePartUpdated({String? partId}) {
    return composition.session.localWireEvents
        .where((event) => event is SesoriMessagePartUpdated && (partId == null || event.part.id == partId))
        .cast<SesoriMessagePartUpdated>()
        .first
        .timeout(const Duration(seconds: 5));
  }

  Future<void> close() async {
    await _subscription.cancel();
    await composition.session.cancel();
    await stopped.timeout(const Duration(seconds: 5));
    await runtime.close();
    await lifecycleService.dispose();
    httpClient.close();
    await plugin.closeEvents();
    await relayServer.close();
  }
}

Future<void> _insertRootSession({required AppDatabase database}) async {
  const projectId = "project-live";
  await database.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await database.sessionDao.insertSession(
    sessionId: _sessionId,
    backendSessionId: _backendSessionId,
    projectId: projectId,
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
    pluginId: _pluginId,
    preservePullRequestScope: false,
  );
}

class _SourcedPlugin(final String pluginId) extends FakeBridgePlugin {
  @override
  String get id => pluginId;
}

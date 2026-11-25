import "dart:convert";
import "dart:io";
import "dart:math";

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:image/image.dart" as img;
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/daos/session_wake_up_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/models/archived_session_file_dto.dart";
import "package:sesori_bridge/src/foundation/sesori_mcp_server.dart";
import "package:sesori_bridge/src/repositories/agent_approval_repository.dart";
import "package:sesori_bridge/src/repositories/agent_page_repository.dart";
import "package:sesori_bridge/src/repositories/models/agent_approval.dart";
import "package:sesori_bridge/src/repositories/models/agent_approval_outcome.dart";
import "package:sesori_bridge/src/repositories/models/sesori_tool_group_ids.dart";
import "package:sesori_bridge/src/repositories/models/session_wake_up.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/models/task_command_edit.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/sesori_mcp_grant_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/session_wake_up_repository.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/groups/pages/page_tool_group.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/groups/tasks/scheduled_task_tool_group.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/groups/tasks/scheduled_task_tool_result_formatter.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/groups/wake_ups/wake_up_tool_group.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/sesori_mcp_request_dispatcher.dart";
import "package:sesori_bridge/src/services/scheduled_task_agent_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_change_description_builder.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_service.dart";
import "package:sesori_bridge/src/services/sesori_mcp_access_service.dart";
import "package:sesori_bridge/src/services/session_wake_up_description_builder.dart";
import "package:sesori_bridge/src/services/session_wake_up_service.dart";
import "package:sesori_bridge/src/services/tool_group_approval_service.dart";
import "package:sesori_bridge/src/services/wake_up_command_description_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolApprovalOutcome, SesoriToolGroupId;
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/agent_page_test_support.dart";
import "../../helpers/arming_test_support.dart";
import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/fakes/wake_up_command_fakes.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";

const _definition = ScheduledTaskDefinition(
  name: "Morning summary",
  prompt: ScheduledTaskPrompt.text(text: "Summarize yesterday"),
  projectId: "/repo",
  pluginId: "fake",
  agent: null,
  model: null,
  variant: null,
  fastMode: false,
  dedicatedWorktree: false,
  schedule: TaskSchedule.daily(time: TaskTimeOfDay(hour: 9, minute: 0)),
  timeZone: "Europe/Bucharest",
  missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
  runMode: TaskRunMode.sameSession(autoCompact: false),
  approvalMode: TaskApprovalMode.ask,
);

/// Enough characters that a transcript page holds only a few messages.
final _filler = "x" * 2500;

String _marker(int index) => "msg-${index.toString().padLeft(2, "0")}";

void main() {
  late AppDatabase db;
  late TestChatHistory history;
  late SesoriMcpGrantRepository grants;
  late SesoriMcpServer server;
  late String taskId;
  late String runId;
  late String token;
  late ScheduledTaskService tasks;
  late ScheduledTaskAgentService agent;
  late _FakeRunService runner;
  late RecordingSessionNotices notices;
  late AgentPageRepository pages;
  late List<AgentApprovalEvent> approvalEvents;
  late SessionWakeUpRepository wakeUps;
  late FakeAutoApproval autoApproval;
  late RecordingScheduledCommands commands;
  late SesoriMcpAccessService access;
  late ToolGroupApprovalService toolGroupApprovals;
  var nextId = 1;

  setUpAll(tz_data.initializeTimeZones);

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    final plugin = FakeBridgePlugin();
    final sessions = singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    history = createTestChatHistory(sessionRepository: sessions);
    final taskRepository = ScheduledTaskRepository(dao: ScheduledTaskDao(database: db));
    final now = DateTime.utc(2026, 11, 15, 10);
    tasks = ScheduledTaskService(
      mutations: RecordingArmingMutations(),
      repository: taskRepository,
      sessionRepository: sessions,
      calculator: const ScheduledTaskOccurrenceCalculator(),
      clock: Clock(() => now),
    );
    addTearDown(tasks.dispose);
    grants = SesoriMcpGrantRepository(random: Random.secure());
    server = await SesoriMcpServer.bindLoopback();
    addTearDown(server.close);
    final approvals = AgentApprovalRepository(random: Random.secure());
    addTearDown(approvals.dispose);
    approvalEvents = [];
    final approvalSubscription = approvals.events.listen(approvalEvents.add);
    addTearDown(approvalSubscription.cancel);
    runner = _FakeRunService();
    notices = RecordingSessionNotices();
    autoApproval = FakeAutoApproval();
    commands = RecordingScheduledCommands();
    final wakeUpService = SessionWakeUpService(
      mutations: RecordingArmingMutations(),
      wakeUps: wakeUps = SessionWakeUpRepository(dao: SessionWakeUpDao(database: db)),
      sessions: sessions,
      calculator: const ScheduledTaskOccurrenceCalculator(),
      notices: notices,
      descriptions: const SessionWakeUpDescriptionBuilder(),
      autoApproval: autoApproval,
      approvals: approvals,
      commandDescriptions: const WakeUpCommandDescriptionBuilder(),
      commands: commands,
      localTimeZone: () => "Europe/Bucharest",
      clock: Clock(() => now),
    );
    agent = ScheduledTaskAgentService(
      tasks: tasks,
      runner: runner,
      taskRepository: taskRepository,
      sessions: sessions,
      projects: singlePluginProjectRepository(
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
        gitCliApi: FakeGitCliApi(),
      ),
      history: history.service,
      approvals: approvals,
      descriptions: const ScheduledTaskChangeDescriptionBuilder(),
      notices: notices,
      wakeUps: wakeUpService,
      toolGroupApprovals: toolGroupApprovals = ToolGroupApprovalService(
        approvals: approvals,
        sessions: sessions,
        autoApproval: autoApproval,
      ),
    );
    access = SesoriMcpAccessService(grants: grants, sessions: sessions);
    final dispatcher = SesoriMcpRequestDispatcher(
      access: access,
      groups: [
        ScheduledTaskToolGroup(agent: agent, formatter: const ScheduledTaskToolResultFormatter()),
        PageToolGroup(
          pages: () {
            final imagesRoot = Directory.systemTemp.createTempSync("page_images_test_");
            addTearDown(() => imagesRoot.deleteSync(recursive: true));
            final built = buildTestAgentPageService(
              database: db,
              sessions: sessions,
              notices: notices,
              imagesRoot: imagesRoot.path,
            );
            pages = built.pages;
            addTearDown(pages.dispose);
            return built.service;
          }(),
        ),
        WakeUpToolGroup(wakeUps: wakeUpService),
      ],
    );
    // As the Orchestrator wires it.
    final subscription = server.requests.listen((request) async {
      await request.respond(
        reply: await dispatcher.dispatch(token: request.token, body: request.body),
      );
    });
    addTearDown(() async {
      await subscription.cancel();
      await dispatcher.drain();
    });

    await insertTestSession(
      db: db,
      sessionId: "s1",
      backendSessionId: "backend-s1",
      pluginId: plugin.id,
      projectId: "/repo",
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      baseBranch: null,
      baseCommit: null,
      agent: null,
      agentModel: null,
    );
    final task = await taskRepository.create(
      definition: _definition,
      nextDueAt: DateTime.utc(2026, 11, 16, 7),
      now: now,
      command: null,
    );
    taskId = task.id;
    await db.customStatement("UPDATE sessions_table SET scheduled_task_id = ? WHERE session_id = 's1'", [taskId]);
    final run = await taskRepository.recordRun(
      taskId: taskId,
      scheduledFor: ScheduledTaskInstant(at: DateTime.utc(2026, 11, 15, 7).millisecondsSinceEpoch, offsetMinutes: 120),
      outcome: const ScheduledTaskRunOutcome.started(
        session: ScheduledTaskRunSession(id: "s1", projectId: "/repo"),
        late: false,
      ),
      firedAt: now,
    );
    runId = run.id;

    token = grants.mint(pluginId: plugin.id, groups: SesoriToolGroupIds.all.toSet());
    grants.bind(token: token, backendSessionId: "backend-s1");
  });

  /// Stores 30 messages, user and assistant in turn, the second with a tool.
  Future<void> captureTranscript() async {
    for (var index = 0; index < 30; index++) {
      final messageId = "m$index";
      await history.service.captureMessage(
        sessionId: "s1",
        message: index.isEven
            ? Message.user(
                id: messageId,
                sessionID: "s1",
                agent: null,
                time: null,
                promptId: null,
                invocation: null,
                handoff: null,
              )
            : Message.assistant(
                id: messageId,
                sessionID: "s1",
                agent: null,
                modelID: null,
                providerID: null,
                time: null,
              ),
      );
      await history.service.capturePart(
        sessionId: "s1",
        part: MessagePart.text(
          id: "p$index",
          sessionID: "s1",
          messageID: messageId,
          text: "${_marker(index)} $_filler",
        ),
      );
      if (index == 1) {
        await history.service.capturePart(
          sessionId: "s1",
          part: const MessagePart.tool(
            id: "tool",
            sessionID: "s1",
            messageID: "m1",
            tool: "bash",
            state: ToolState(
              status: ToolStatus.completed,
              title: null,
              shellCommand: "ls",
              output: "a.txt",
              error: null,
            ),
          ),
        );
      }
    }
  }

  /// The user's answer to agent approval [requestId].
  Future<AgentApprovalOutcome> answer({required String requestId, required PermissionReply reply}) async =>
      switch (await agent.settle(requestId: requestId, reply: reply)) {
        AgentApprovalAnswered(:final outcome) => outcome,
        WakeUpCommandAnswered() => fail("$requestId is a wake-up command approval"),
        ToolGroupChangeAnswered() => fail("$requestId is a tool group approval"),
        NotAgentApproval() => fail("$requestId is not an agent approval"),
      };

  Future<http.Response> post({required String bearer, required Map<String, Object?> message}) {
    return http.post(
      server.url,
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $bearer"},
      body: jsonEncode(message),
    );
  }

  Future<Map<String, dynamic>> rpc({
    required String method,
    required Map<String, Object?>? params,
    String? bearer,
  }) async {
    final response = await post(
      bearer: bearer ?? token,
      message: {"jsonrpc": "2.0", "id": nextId++, "method": method, "params": ?params},
    );
    expect(response.statusCode, HttpStatus.ok);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// The tool result's text and whether it is an error.
  Future<({String text, bool isError})> call({
    required String tool,
    required Map<String, Object?> arguments,
    String? bearer,
  }) async {
    final response = await rpc(
      method: "tools/call",
      params: {"name": tool, "arguments": arguments},
      bearer: bearer,
    );
    final result = response["result"] as Map<String, dynamic>;
    final content = (result["content"] as List<dynamic>).single as Map<String, dynamic>;
    expect(content["type"], "text");
    return (text: content["text"] as String, isError: result["isError"] as bool);
  }

  group("protocol", () {
    test("initialize echoes a known protocol version and names the server", () async {
      final response = await rpc(method: "initialize", params: {"protocolVersion": "2025-06-18"});

      final result = response["result"] as Map<String, dynamic>;
      expect(response["id"], isNotNull);
      expect(result["protocolVersion"], "2025-06-18");
      expect(result["serverInfo"], containsPair("name", "sesori_bridge"));
      expect(result["capabilities"], {
        "tools": {"listChanged": false},
      });
    });

    test("initialize offers its newest version for an unknown one", () async {
      final response = await rpc(method: "initialize", params: {"protocolVersion": "1999-01-01"});

      expect((response["result"] as Map<String, dynamic>)["protocolVersion"], "2025-11-25");
    });

    test("a notification is accepted without a body", () async {
      final response = await post(
        bearer: token,
        message: {"jsonrpc": "2.0", "method": "notifications/initialized"},
      );

      expect(response.statusCode, HttpStatus.accepted);
      expect(response.body, isEmpty);
    });

    test("ping answers and tools/list names every tool", () async {
      expect((await rpc(method: "ping", params: null))["result"], <String, dynamic>{});

      final tools = ((await rpc(method: "tools/list", params: null))["result"] as Map<String, dynamic>)["tools"];
      expect(
        [for (final tool in tools as List<dynamic>) (tool as Map<String, dynamic>)["name"]],
        [
          "list_tasks",
          "get_task",
          "list_task_runs",
          "get_task_run_transcript",
          "create_task",
          "update_task",
          "pause_task",
          "resume_task",
          "run_task_now",
          "send_page",
          "schedule_wakeup",
          "list_wakeups",
          "cancel_wakeup",
        ],
      );
      for (final tool in tools) {
        final name = (tool as Map<String, dynamic>)["name"] as String;
        final readOnly = name.startsWith("list_") || name.startsWith("get_") || name == "send_page";
        expect(tool["annotations"], {"readOnlyHint": readOnly});
        expect(tool["inputSchema"], containsPair("type", "object"));
      }
    });

    // The exact text agents read. Set SESORI_UPDATE_GOLDENS=1 to rewrite the
    // file after an intended change, and review its diff.
    test("tools/list matches the golden", () async {
      final result = (await rpc(method: "tools/list", params: null))["result"];
      final listed = "${const JsonEncoder.withIndent("  ").convert(result)}\n";
      final golden = File("test/bridge/sesori_mcp/goldens/tools_list.json");

      if (Platform.environment["SESORI_UPDATE_GOLDENS"] == "1") golden.writeAsStringSync(listed);
      expect(listed, golden.readAsStringSync());
    });

    test("two groups offering one tool name fail at construction", () {
      final tasks = ScheduledTaskToolGroup(agent: agent, formatter: const ScheduledTaskToolResultFormatter());

      expect(
        () => SesoriMcpRequestDispatcher(access: access, groups: [tasks, tasks]),
        throwsA(isA<AssertionError>()),
      );
    });

    test("update_task says once to leave out the fields an agent is not changing", () async {
      final tools = ((await rpc(method: "tools/list", params: null))["result"] as Map<String, dynamic>)["tools"];
      Map<String, dynamic> tool(String name) =>
          (tools as List<dynamic>).cast<Map<String, dynamic>>().singleWhere((tool) => tool["name"] == name);
      Map<String, dynamic> properties(String name) =>
          (tool(name)["inputSchema"] as Map<String, dynamic>)["properties"] as Map<String, dynamic>;
      const hint = "Leave out every field you are not changing; left-out fields keep their value.";
      const settings = ["schedule", "time_zone", "missed_run_policy", "run_mode", "model", "effort", "approval_mode"];

      expect(tool("update_task")["description"], contains(hint));
      for (final setting in settings) {
        expect((properties("update_task")[setting] as Map<String, dynamic>)["description"], isNot(contains(hint)));
        expect((properties("create_task")[setting] as Map<String, dynamic>)["description"], isNot(contains(hint)));
      }
      expect((properties("update_task")["schedule"] as Map<String, dynamic>)["description"], "Same as create_task.");
    });

    test("a grant lists, describes and answers only the tool groups it was minted with", () async {
      final pagesOnly = grants.mint(pluginId: "fake", groups: {SesoriToolGroupIds.pages});
      grants.bind(token: pagesOnly, backendSessionId: "backend-s1");

      final tools = ((await rpc(method: "tools/list", params: null, bearer: pagesOnly))["result"] as Map)["tools"];
      expect([for (final tool in tools as List<dynamic>) (tool as Map<String, dynamic>)["name"]], ["send_page"]);
      final initialized = (await rpc(method: "initialize", params: {}, bearer: pagesOnly))["result"] as Map;
      expect(initialized["instructions"], allOf(contains("send_page"), isNot(contains("list_tasks"))));
      final outside = await rpc(method: "tools/call", params: {"name": "list_tasks"}, bearer: pagesOnly);
      expect(outside["error"], {"code": -32602, "message": "Unknown tool: list_tasks"});
    });

    test("malformed JSON, unknown methods and unknown tools are JSON-RPC errors", () async {
      final malformed = await http.post(
        server.url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: "{not json",
      );
      expect((jsonDecode(malformed.body) as Map<String, dynamic>)["error"], containsPair("code", -32700));
      expect((await rpc(method: "resources/list", params: null))["error"], containsPair("code", -32601));
      // Claude Code probes this before initialize.
      expect((await rpc(method: "server/discover", params: null))["error"], containsPair("code", -32601));
      expect(
        (await rpc(method: "tools/call", params: {"name": "delete_everything"}))["error"],
        containsPair("code", -32602),
      );
    });
  });

  group("caller identity", () {
    test("a token this bridge never minted gets 401 for every method", () async {
      final response = await post(
        bearer: "made-up",
        message: {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": <String, Object?>{}},
      );

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test("a token from before a restart gets 401", () async {
      final oldBridge = SesoriMcpGrantRepository(random: Random.secure());
      final stale = oldBridge.mint(pluginId: "fake", groups: SesoriToolGroupIds.all.toSet());
      oldBridge.bind(token: stale, backendSessionId: "backend-s1");

      final response = await post(bearer: stale, message: {"jsonrpc": "2.0", "id": 1, "method": "tools/list"});

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test("a launch not yet bound can connect but no tool answers it", () async {
      final unbound = grants.mint(pluginId: "fake", groups: SesoriToolGroupIds.all.toSet());

      expect((await rpc(method: "initialize", params: {}, bearer: unbound))["result"], isNotNull);
      expect((await rpc(method: "tools/list", params: null, bearer: unbound))["result"], isNotNull);
      final result = await call(tool: "list_tasks", arguments: {}, bearer: unbound);
      expect(result.isError, isTrue);
      expect(result.text, contains("not linked"));
    });
  });

  group("read tools", () {
    test("list_tasks lists every task and marks the caller's project", () async {
      final result = await call(tool: "list_tasks", arguments: {});

      expect(result.isError, isFalse);
      expect(result.text, contains("Morning summary (id: $taskId)"));
      expect(result.text, contains("project: /repo (this session's project)"));
      expect(result.text, contains("schedule: daily at 09:00 (Europe/Bucharest)"));
      expect(result.text, contains("next run: 2026-11-16 09:00 (UTC+02:00)"));
      expect((await call(tool: "list_tasks", arguments: {"project_id": ""})).text, contains("Morning summary"));
      final unknown = await call(tool: "list_tasks", arguments: {"project_id": "current"});
      expect(unknown.isError, isTrue);
      expect(
        unknown.text,
        "Invalid arguments for list_tasks: project_id is not a known project; leave it out to list every task.",
      );
    });

    test("get_task without an id shows the caller's own task", () async {
      final own = await call(tool: "get_task", arguments: {});

      expect(own.isError, isFalse);
      expect(own.text, contains("the task this session runs for"));
      expect(own.text, contains("Summarize yesterday"));
      expect(own.text, contains("runs in: one session for every run"));

      final emptyId = await call(tool: "get_task", arguments: {"task_id": ""});
      expect(emptyId.isError, isFalse);
      expect(emptyId.text, contains("the task this session runs for"));

      final missing = await call(tool: "get_task", arguments: {"task_id": "stk_missing"});
      expect(missing.isError, isTrue);
      expect(missing.text, contains("No scheduled task stk_missing"));
    });

    test("list_task_runs shows each run with the start of its final reply", () async {
      await captureTranscript();

      final result = await call(tool: "list_task_runs", arguments: {"task_id": taskId});

      expect(result.isError, isFalse);
      expect(result.text, contains("run $runId: 2026-11-15 09:00 (UTC+02:00), started"));
      expect(result.text, contains("final reply: ${_marker(29)} "));
      expect(result.text, contains("more characters)"));
    });

    test("a run's final reply skips Sesori notices and the agent's answer to them", () async {
      var index = 0;
      Future<void> capture({required MessageSender? sender, required String text}) async {
        final id = "n${index++}";
        await history.service.captureMessage(
          sessionId: "s1",
          message: switch (sender) {
            null => Message.user(
              id: id,
              sessionID: "s1",
              agent: null,
              time: null,
              promptId: null,
              invocation: null,
              handoff: null,
            ),
            final sender => Message.assistant(
              id: id,
              sessionID: "s1",
              agent: null,
              modelID: null,
              providerID: null,
              time: null,
              sender: sender,
            ),
          },
        );
        await history.service.capturePart(
          sessionId: "s1",
          part: MessagePart.text(id: "$id-text", sessionID: "s1", messageID: id, text: text),
        );
      }

      Future<String> runs() async => (await call(tool: "list_task_runs", arguments: {"task_id": taskId})).text;

      await capture(sender: null, text: "Run prompt");
      await capture(sender: MessageSender.agent, text: "Run reply");
      await capture(sender: MessageSender.sesori, text: "You allowed pausing it.");
      expect(await runs(), contains("final reply: Run reply"));

      await capture(sender: MessageSender.agent, text: "Noted");
      expect(await runs(), contains("final reply: Run reply"));

      await capture(sender: null, text: "Next run prompt");
      await capture(sender: MessageSender.agent, text: "Next run reply");
      expect(await runs(), contains("final reply: Next run reply"));
    });

    test("invalid arguments come back as a tool error naming the field", () async {
      final missing = await call(tool: "list_task_runs", arguments: {});
      final empty = await call(tool: "list_task_runs", arguments: {"task_id": ""});
      final wrongType = await call(
        tool: "get_task_run_transcript",
        arguments: {"task_id": taskId, "run_id": runId, "page": "2"},
      );

      expect(missing.isError, isTrue);
      expect(missing.text, "Invalid arguments for list_task_runs: task_id is required.");
      expect(empty.text, "Invalid arguments for list_task_runs: task_id is required.");
      expect(wrongType.text, "Invalid arguments for get_task_run_transcript: page is not valid; see its input schema.");
    });

    test("get_task_run_transcript pages from newest to oldest without gaps or overlaps", () async {
      await captureTranscript();

      final seen = <int>[];
      int? page;
      String text;
      var pages = 0;
      do {
        final result = await call(
          tool: "get_task_run_transcript",
          arguments: {"task_id": taskId, "run_id": runId, "page": ?page},
        );
        expect(result.isError, isFalse);
        text = result.text;
        expect(text.length, lessThan(ScheduledTaskToolResultFormatter.transcriptPageChars + 1000));
        final markers = [
          for (final match in RegExp(r"msg-(\d\d)").allMatches(text)) int.parse(match.group(1) ?? ""),
        ];
        seen.insertAll(0, markers);
        final next = RegExp(r"page: (\d+)").firstMatch(text)?.group(1);
        page = next == null ? null : int.parse(next);
        pages++;
      } while (page != null);

      expect(seen, List.generate(30, (index) => index));
      expect(pages, greaterThan(1));
      expect(text, contains("This is the start of the session."));
      expect(text, contains("[tool bash: ls] completed"));
      expect(text, contains("result: a.txt"));
      expect(text, contains("[user]"));
      expect(text, contains("[assistant]"));
    });

    test("get_task_run_transcript reads an archived run's session", () async {
      await captureTranscript();
      await history.repository.exportSession(
        session: const StoredSession(
          id: "s1",
          backendSessionId: "backend-s1",
          pluginId: "fake",
          projectId: "/repo",
          parentSessionId: null,
          directory: "/repo",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: 300,
          baseBranch: null,
          baseCommit: null,
        ),
        title: null,
        createdAt: 1,
        updatedAt: 2,
        archivedAt: 300,
        completeness: ArchivedSessionCompleteness.complete,
      );
      await history.service.purgeSessionHistory(sessionId: "s1");
      await db.customStatement("UPDATE sessions_table SET archived_at = 300 WHERE session_id = 's1'");

      final result = await call(tool: "get_task_run_transcript", arguments: {"task_id": taskId, "run_id": runId});

      expect(result.isError, isFalse);
      expect(result.text, contains(_marker(29)));
      expect(result.text, contains("Older messages remain"));
    });

    test("get_task_run_transcript names an unknown run", () async {
      final result = await call(tool: "get_task_run_transcript", arguments: {"task_id": taskId, "run_id": "str_x"});

      expect(result.isError, isTrue);
      expect(result.text, contains("No run str_x"));
    });
  });

  group("proposing tools", () {
    /// The request the last proposal raised.
    PendingPermission asked() => approvalEvents.whereType<AgentApprovalAsked>().last.permission;

    test("pause_task asks the user and Allow applies it", () async {
      final result = await call(tool: "pause_task", arguments: {"task_id": taskId});

      expect(result.isError, isFalse);
      expect(
        result.text,
        "Sent to the user for approval. Nothing happens unless they allow it. Sesori will message this session with their answer.",
      );
      final approval = asked();
      expect(approval.sessionID, "s1");
      expect(approval.tool, "Sesori: pause task");
      expect(approval.allowAlways, isFalse);
      expect(
        approval.description,
        "Project: repo\n\n**Pause “Morning summary”**\n\nAsked by a scheduled run of this task.",
      );
      expect((await tasks.list()).items.single.enabled, isTrue);

      expect(await answer(requestId: approval.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect((await tasks.list()).items.single.enabled, isFalse);
      expect(agent.pendingPermissions(sessionId: "s1"), isEmpty);
      final delivered = notices.delivered.single;
      expect(delivered.sessionId, "s1");
      expect(delivered.notice.summary, "You allowed pausing “Morning summary”.");
      expect(delivered.notice.guidance, "The change is saved. Reply in one short line.");
    });

    test("update_task asks the user and Allow applies it", () async {
      final result = await call(
        tool: "update_task",
        arguments: {"task_id": taskId, "prompt": "Summarize the week", "approval_mode": "approveAll"},
      );

      expect(result.isError, isFalse);
      expect(
        result.text,
        "Sent to the user for approval. If they allow it, it applies to the next run. Sesori will message this session with their answer.",
      );
      final approval = asked();
      expect(approval.tool, "Sesori: update task");
      expect(approval.description, startsWith("**Turns on Approve everything"));
      expect((await tasks.list()).items.single.definition.approvalMode, TaskApprovalMode.ask);

      expect(await answer(requestId: approval.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      final updated = (await tasks.list()).items.single.definition;
      expect(updated.prompt, const ScheduledTaskPrompt.text(text: "Summarize the week"));
      expect(updated.approvalMode, TaskApprovalMode.approveAll);
    });

    test("update_task reads the empty fields a strict-schema model fills in as left out", () async {
      final result = await call(
        tool: "update_task",
        arguments: {
          "task_id": taskId,
          "name": "",
          "prompt": "Summarize the week",
          "command_arguments": "",
          "schedule": "",
          "time_zone": "",
          "missed_run_policy": "",
          "run_mode": "",
          "model": "",
          "effort": "",
          "approval_mode": "",
        },
      );

      expect(result.isError, isFalse, reason: result.text);
      expect(asked().tool, "Sesori: update task");
      expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      final updated = (await tasks.list()).items.single.definition;
      expect(updated.prompt, const ScheduledTaskPrompt.text(text: "Summarize the week"));
      expect(updated.name, "Morning summary");
      expect(updated.model, isNull);
      expect(updated.approvalMode, TaskApprovalMode.ask);
    });

    test("update_task asks only for the fields that differ from the task", () async {
      final result = await call(
        tool: "update_task",
        arguments: {
          "task_id": taskId,
          "name": "Morning summary",
          "prompt": "Summarize the week",
          "schedule": {
            "kind": "daily",
            "time": {"hour": 9, "minute": 0},
          },
          "time_zone": "Europe/Bucharest",
          "missed_run_policy": "runWhenBack",
          "run_mode": {"kind": "sameSession", "autoCompact": false},
          "approval_mode": "ask",
        },
      );

      expect(result.isError, isFalse, reason: result.text);
      expect(
        asked().description,
        "Project: repo\n\n**Update “Morning summary”**\n\nPrompt changes:\n\n```diff words=0:10-19;1:10-18\n-Summarize yesterday\n+Summarize the week\n```\n\n"
        "Asked by a scheduled run of this task.",
      );
    });

    test("arguments that do not parse name the field and ask nobody", () async {
      Future<String> createWith({required Map<String, Object?> overrides}) async {
        final result = await call(
          tool: "create_task",
          arguments: {
            "name": "Daily check",
            "prompt": "Check the build",
            "schedule": {
              "kind": "daily",
              "time": {"hour": 9, "minute": 0},
            },
            "time_zone": "Europe/Bucharest",
            ...overrides,
          },
        );
        expect(result.isError, isTrue, reason: result.text);
        return result.text;
      }

      expect(
        await createWith(
          overrides: {
            "schedule": {"kind": "daily"},
          },
        ),
        "Invalid arguments for create_task: schedule.time is required when schedule.kind is daily.",
      );
      expect(
        await createWith(
          overrides: {
            "schedule": {"kind": "hourly"},
          },
        ),
        "Invalid arguments for create_task: schedule.kind must be one of once, daily, weekdays, weekly, everyHours.",
      );
      expect(
        await createWith(
          overrides: {
            "run_mode": {"kind": "sameSession"},
          },
        ),
        "Invalid arguments for create_task: run_mode.autoCompact is required when run_mode.kind is sameSession.",
      );
      expect(
        await createWith(overrides: {"time_zone": ""}),
        "Invalid arguments for create_task: time_zone is required.",
      );
      expect(
        await createWith(overrides: {"approval_mode": "sometimes"}),
        "Invalid arguments for create_task: approval_mode is not valid; see its input schema.",
      );
      expect(
        await createWith(overrides: {"project_id": "current"}),
        "Unknown project_id; find project ids with list_tasks.",
      );
      expect(approvalEvents, isEmpty);
    });

    test("Allow applies nothing once what the request showed changed", () async {
      Future<ScheduledTaskDefinition> definition() async => (await tasks.list()).items.single.definition;
      Future<void> edit(ScheduledTaskDefinition Function(ScheduledTaskDefinition definition) change) async {
        await tasks.update(
          taskId: taskId,
          definition: change(await definition()),
          command: const TaskCommandUnchanged(),
        );
      }

      // A second project the task can move to.
      await insertTestSession(
        db: db,
        sessionId: "s-other",
        backendSessionId: "backend-s-other",
        pluginId: _definition.pluginId,
        projectId: "/other",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      for (final (tool, arguments, userEdit) in [
        (
          "update_task",
          {"task_id": taskId, "name": "Evening summary"},
          () => edit((definition) => definition.copyWith(name: "Night summary")),
        ),
        // Shown for one project, it never applies in another.
        (
          "update_task",
          {"task_id": taskId, "prompt": "Summarize the week"},
          () => edit((definition) => definition.copyWith(projectId: "/other")),
        ),
        // A schedule was shown in its time zone.
        (
          "update_task",
          {
            "task_id": taskId,
            "schedule": {
              "kind": "daily",
              "time": {"hour": 10, "minute": 0},
            },
          },
          () => edit((definition) => definition.copyWith(timeZone: "America/New_York")),
        ),
        ("pause_task", {"task_id": taskId}, () => tasks.setEnabled(taskId: taskId, enabled: false)),
        (
          "run_task_now",
          {"task_id": taskId},
          () => edit((definition) => definition.copyWith(approvalMode: TaskApprovalMode.approveAll)),
        ),
      ]) {
        await tasks.setEnabled(taskId: taskId, enabled: true);
        await edit((definition) => definition.copyWith(projectId: "/repo", approvalMode: TaskApprovalMode.ask));
        expect(
          (await call(tool: tool, arguments: arguments)).isError,
          isFalse,
          reason: tool,
        );
        await userEdit();

        expect(
          await answer(requestId: asked().id, reply: PermissionReply.once),
          isA<AgentApprovalStale>(),
          reason: tool,
        );
      }
      expect((await definition()).name, "Night summary");
      expect(runner.ranNow, isEmpty);

      await tasks.setEnabled(taskId: taskId, enabled: false);
      expect((await call(tool: "resume_task", arguments: {"task_id": taskId})).isError, isFalse);
      await edit(
        (definition) =>
            definition.copyWith(schedule: const TaskSchedule.daily(time: TaskTimeOfDay(hour: 8, minute: 0))),
      );
      expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect((await tasks.list()).items.single.enabled, isFalse);
      expect(
        notices.delivered.last.notice.summary,
        "You allowed resuming “Night summary”, but it had changed since, so nothing was applied.",
      );
    });

    test("Allow applies a request on top of changes to fields it does not touch", () async {
      await call(tool: "update_task", arguments: {"task_id": taskId, "prompt": "Summarize the week"});
      final edit = asked();
      await call(tool: "pause_task", arguments: {"task_id": taskId});
      final pause = asked();
      final current = (await tasks.list()).items.single.definition;
      await tasks.update(
        taskId: taskId,
        definition: current.copyWith(name: "Weekly summary"),
        command: const TaskCommandUnchanged(),
      );

      expect(await answer(requestId: pause.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await answer(requestId: edit.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());

      final task = (await tasks.list()).items.single;
      expect(task.enabled, isFalse);
      expect(task.definition.name, "Weekly summary");
      expect(task.definition.prompt, const ScheduledTaskPrompt.text(text: "Summarize the week"));
    });

    test("a prompt edit asked without the Approve everything warning is stale once the warning applies", () async {
      await call(tool: "update_task", arguments: {"task_id": taskId, "prompt": "Summarize the week"});
      final edit = asked();
      await call(tool: "update_task", arguments: {"task_id": taskId, "approval_mode": "approveAll"});
      final approveAll = asked();

      expect(await answer(requestId: approveAll.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await answer(requestId: edit.id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect(
        (await tasks.list()).items.single.definition.prompt,
        const ScheduledTaskPrompt.text(text: "Summarize yesterday"),
      );
    });

    test("an allowed change that no longer validates on the current task is stale", () async {
      await call(tool: "update_task", arguments: {"task_id": taskId, "time_zone": "Pacific/Kiritimati"});
      final current = (await tasks.list()).items.single.definition;
      // 18:00 in Bucharest is still ahead; 18:00 in Kiritimati has passed.
      await tasks.update(
        taskId: taskId,
        definition: current.copyWith(
          schedule: const TaskSchedule.once(
            at: TaskLocalDateTime(year: 2026, month: 11, day: 15, hour: 18, minute: 0),
          ),
        ),
        command: const TaskCommandUnchanged(),
      );

      expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect((await tasks.list()).items.single.definition.timeZone, "Europe/Bucharest");
    });

    test("Allow applies nothing once the task is deleted", () async {
      await call(tool: "pause_task", arguments: {"task_id": taskId});
      await tasks.delete(taskId: taskId);

      expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalStale>());
    });

    test("run_task_now runs the task on Allow, and Reject drops a request", () async {
      await call(tool: "run_task_now", arguments: {"task_id": taskId});
      expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(runner.ranNow, [taskId]);

      runner.outcome = const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.projectMissing, attempt: null);
      await call(tool: "run_task_now", arguments: {"task_id": taskId});
      expect(
        await answer(requestId: asked().id, reply: PermissionReply.once),
        isA<AgentApprovalRunNotStarted>(),
      );

      await call(tool: "pause_task", arguments: {"task_id": taskId});
      expect(await answer(requestId: asked().id, reply: PermissionReply.reject), isA<AgentApprovalRejected>());
      expect((await tasks.list()).items.single.enabled, isTrue);

      expect(notices.delivered.map((delivered) => delivered.notice.summary), [
        "You allowed running “Morning summary” now.",
        "You allowed running “Morning summary” now, but it didn’t start.",
        "You didn’t allow pausing “Morning summary”.",
      ]);
      expect(notices.delivered.map((delivered) => delivered.notice.guidance), [
        "The run started. Reply in one short line.",
        "The project folder is missing. Reply in one short line.",
        "Nothing changed. Don't propose it again unless they ask. Reply in one short line.",
      ]);
    });

    test("several requests wait on one session and each is answered on its own", () async {
      for (final pauseFirst in [true, false]) {
        await tasks.setEnabled(taskId: taskId, enabled: true);
        final prompt = "Summarize ${pauseFirst ? "the week" : "the month"}";
        await call(tool: "pause_task", arguments: {"task_id": taskId});
        final pause = asked();
        final result = await call(tool: "update_task", arguments: {"task_id": taskId, "prompt": prompt});
        final edit = asked();

        expect(
          result.text,
          "Sent to the user for approval. If they allow it, it applies to the next run. Sesori will message this session with their answer.",
        );
        expect(agent.pendingPermissions(sessionId: "s1").map((permission) => permission.id), [pause.id, edit.id]);
        for (final request in pauseFirst ? [pause, edit] : [edit, pause]) {
          expect(
            await answer(requestId: request.id, reply: PermissionReply.once),
            isA<AgentApprovalApplied>(),
            reason: "pause first: $pauseFirst",
          );
        }
        final task = (await tasks.list()).items.single;
        expect(task.enabled, isFalse);
        expect(task.definition.prompt, ScheduledTaskPrompt.text(text: prompt));
        expect(agent.pendingPermissions(sessionId: "s1"), isEmpty);
      }
    });

    test("of two requests that change the same field, the second is stale", () async {
      await call(tool: "update_task", arguments: {"task_id": taskId, "prompt": "Summarize the week"});
      final first = asked();
      await call(tool: "update_task", arguments: {"task_id": taskId, "prompt": "Summarize the month"});
      final second = asked();
      await call(tool: "pause_task", arguments: {"task_id": taskId});
      final firstPause = asked();
      await call(tool: "pause_task", arguments: {"task_id": taskId});
      final secondPause = asked();

      expect(await answer(requestId: first.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await answer(requestId: second.id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect(await answer(requestId: firstPause.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await answer(requestId: secondPause.id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect(
        (await tasks.list()).items.single.definition.prompt,
        const ScheduledTaskPrompt.text(text: "Summarize the week"),
      );
    });

    test("create_task makes a task in the caller's project and harness on Allow", () async {
      final result = await call(
        tool: "create_task",
        arguments: {
          "name": "Weekly cleanup",
          "prompt": "Delete merged branches",
          "schedule": {
            "kind": "weekly",
            "days": ["friday"],
            "time": {"hour": 17, "minute": 30},
          },
          "time_zone": "Europe/Bucharest",
          "model": "anthropic/claude-sonnet",
        },
      );
      expect(result.isError, isFalse);
      expect(asked().tool, "Sesori: create task");

      final outcome = await answer(requestId: asked().id, reply: PermissionReply.once);
      final createdTask = (await tasks.list()).items.singleWhere((task) => task.definition.name == "Weekly cleanup");
      expect(outcome, isA<AgentApprovalCreated>().having((created) => created.taskId, "taskId", createdTask.id));
      expect(notices.delivered.single.notice.summary, "You allowed creating “Weekly cleanup”.");
      expect(notices.delivered.single.notice.guidance, contains("The new task's id is ${createdTask.id}."));
      final created = createdTask.definition;
      expect(created.projectId, "/repo");
      expect(created.pluginId, "fake");
      expect(created.model, const PromptModel(providerID: "anthropic", modelID: "claude-sonnet"));
      expect(created.dedicatedWorktree, isFalse);
      expect(created.approvalMode, TaskApprovalMode.ask);
    });

    group("task commands", () {
      Future<String?> storedCommand() async => (await tasks.list()).items.single.command;

      test("create_task shows the command in its request and saves it on Allow", () async {
        await call(
          tool: "create_task",
          arguments: {
            "name": "Weekly cleanup",
            "prompt": "Delete merged branches",
            "schedule": {
              "kind": "weekly",
              "days": ["friday"],
              "time": {"hour": 17, "minute": 30},
            },
            "time_zone": "Europe/Bucharest",
            "command": "git fetch --prune",
          },
        );
        expect(
          asked().description,
          contains("Runs this command before each run's prompt:\n\n```\ngit fetch --prune\n```"),
        );

        await answer(requestId: asked().id, reply: PermissionReply.once);

        final created = (await tasks.list()).items.singleWhere((task) => task.definition.name == "Weekly cleanup");
        expect(created.command, "git fetch --prune");
        final shown = await call(tool: "get_task", arguments: {"task_id": created.id});
        expect(shown.text, contains("command, run before each run's prompt:\n```\ngit fetch --prune\n```\nprompt:"));
      });

      test("update_task sets, changes and removes the command on Allow", () async {
        await call(tool: "update_task", arguments: {"task_id": taskId, "command": "git fetch"});
        expect(asked().description, contains("Adds a command, run before each run's prompt:"));
        expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
        expect(await storedCommand(), "git fetch");

        await call(tool: "update_task", arguments: {"task_id": taskId, "command": "git pull"});
        expect(asked().description, contains("```diff words=0:4-9;1:4-8\n-git fetch\n+git pull\n```"));
        expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
        expect(await storedCommand(), "git pull");

        // An app edit sends the definition alone and keeps the command.
        await tasks.update(
          taskId: taskId,
          definition: (await tasks.list()).items.single.definition.copyWith(name: "Morning pull"),
          command: const TaskCommandUnchanged(),
        );
        expect(await storedCommand(), "git pull");

        await call(tool: "update_task", arguments: {"task_id": taskId, "remove_command": true, "command": ""});
        expect(asked().description, contains("Stops running this command:"));
        expect(await answer(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
        expect(await storedCommand(), isNull);
      });

      test("a command request is stale once another changed the command", () async {
        await call(tool: "update_task", arguments: {"task_id": taskId, "command": "make"});
        final first = asked();
        await call(tool: "update_task", arguments: {"task_id": taskId, "command": "make test"});
        final second = asked();

        expect(await answer(requestId: second.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
        expect(await answer(requestId: first.id, reply: PermissionReply.once), isA<AgentApprovalStale>());
        expect(await storedCommand(), "make test");
      });

      test("run_task_now shows the command it runs", () async {
        await call(tool: "update_task", arguments: {"task_id": taskId, "command": "make"});
        await answer(requestId: asked().id, reply: PermissionReply.once);

        await call(tool: "run_task_now", arguments: {"task_id": taskId});

        expect(asked().description, contains("Runs this command before each run's prompt:\n\n```\nmake\n```"));
      });

      test("an update cannot both set and remove the command, nor give a slash-command task one", () async {
        final both = await call(
          tool: "update_task",
          arguments: {"task_id": taskId, "command": "make", "remove_command": true},
        );
        expect(both.isError, isTrue);
        expect(both.text, contains("Pass command or remove_command, not both."));

        await tasks.update(
          taskId: taskId,
          definition: (await tasks.list()).items.single.definition.copyWith(
            prompt: const ScheduledTaskPrompt.command(name: "review", source: CommandSource.skill, arguments: null),
          ),
          command: const TaskCommandUnchanged(),
        );
        final slash = await call(tool: "update_task", arguments: {"task_id": taskId, "command": "make"});
        expect(slash.isError, isTrue);
        expect(slash.text, contains("cannot also run a shell command"));
      });
    });

    test("a create or update the bridge could not save is refused before anyone is asked", () async {
      final invalid = await call(
        tool: "create_task",
        arguments: {
          "name": "Broken",
          "prompt": "x",
          "schedule": {
            "kind": "daily",
            "time": {"hour": 9, "minute": 0},
          },
          "time_zone": "Mars/Olympus",
        },
      );
      final unchanged = await call(tool: "update_task", arguments: {"task_id": taskId, "name": "Morning summary"});
      final command = await call(tool: "update_task", arguments: {"task_id": taskId, "command_arguments": "--all"});
      final badModel = await call(tool: "update_task", arguments: {"task_id": taskId, "model": "no-provider"});

      expect(invalid.isError, isTrue);
      expect(invalid.text, contains("Unknown time_zone"));
      expect(unchanged.isError, isTrue);
      expect(unchanged.text, contains("nothing would change"));
      expect(command.isError, isTrue);
      expect(command.text, contains("This task sends text"));
      expect(badModel.isError, isTrue);
      expect(badModel.text, "Invalid arguments for update_task: model must be provider/model.");
      expect(approvalEvents, isEmpty);
    });

    test("a model the harness does not offer is refused before anyone is asked", () async {
      runner.offeredModels = {const PromptModel(providerID: "anthropic", modelID: "claude-sonnet")};

      final unknown = await call(tool: "update_task", arguments: {"task_id": taskId, "model": "github/copilot"});
      expect(unknown.isError, isTrue);
      expect(unknown.text, contains("model is not one this task's harness offers"));
      expect(approvalEvents, isEmpty);

      final offered = await call(
        tool: "update_task",
        arguments: {"task_id": taskId, "model": "anthropic/claude-sonnet"},
      );
      expect(offered.isError, isFalse);
      expect(asked().description, contains("anthropic/claude-sonnet"));
    });

    test("a subagent's request shows on its root session", () async {
      for (final (child, parent) in [("s2", "s1"), ("s3", "s2")]) {
        await insertTestSession(
          db: db,
          sessionId: child,
          backendSessionId: "backend-$child",
          pluginId: "fake",
          projectId: "/repo",
          isDedicated: false,
          createdAt: 1,
          worktreePath: null,
          baseBranch: null,
          baseCommit: null,
          agent: null,
          agentModel: null,
        );
        await db.customStatement("UPDATE sessions_table SET parent_session_id = ? WHERE session_id = ?", [
          parent,
          child,
        ]);
      }
      final grandchild = grants.mint(pluginId: "fake", groups: SesoriToolGroupIds.all.toSet());
      grants.bind(token: grandchild, backendSessionId: "backend-s3");

      await call(tool: "pause_task", arguments: {"task_id": taskId}, bearer: grandchild);
      await call(tool: "run_task_now", arguments: {"task_id": taskId});

      final [fromGrandchild, fromRoot] = [
        for (final event in approvalEvents.whereType<AgentApprovalAsked>()) event.permission,
      ];
      expect(fromGrandchild.sessionID, "s3");
      expect(fromGrandchild.displaySessionId, "s1");
      expect(fromRoot.sessionID, "s1");
      expect(fromRoot.displaySessionId, isNull);

      await answer(requestId: fromGrandchild.id, reply: PermissionReply.once);
      await answer(requestId: fromRoot.id, reply: PermissionReply.once);
      final [toGrandchild, toRoot] = notices.delivered;
      expect(toGrandchild.sessionId, "s1");
      expect(
        toGrandchild.notice.guidance,
        "A sub-agent of this session made this request. The change is saved. Reply in one short line.",
      );
      expect(toRoot.sessionId, "s1");
      expect(toRoot.notice.guidance, "The run started. Reply in one short line.");
    });

    test("a proposal for a missing task or a task already in that state asks nobody", () async {
      final missing = await call(tool: "run_task_now", arguments: {"task_id": "stk_missing"});
      final running = await call(tool: "resume_task", arguments: {"task_id": taskId});

      expect(missing.isError, isTrue);
      expect(missing.text, contains("No scheduled task stk_missing"));
      expect(running.isError, isTrue);
      expect(running.text, contains("already in that state"));
      expect(approvalEvents, isEmpty);
    });
  });

  group("send_page", () {
    late Directory files;

    setUp(() {
      files = Directory.systemTemp.createTempSync("send_page_test_");
      addTearDown(() => files.deleteSync(recursive: true));
    });

    /// A 3×2 PNG at [name], padded with [padding] bytes after its end.
    String png(String name, {int padding = 0}) {
      final file = File("${files.path}/$name")
        ..writeAsBytesSync([...img.encodePng(img.Image(width: 3, height: 2)), ...List.filled(padding, 0)]);
      return file.path;
    }

    Map<String, Object?> choice(String id, {List<Map<String, Object?>>? options}) => {
      "id": id,
      "title": "Pick $id",
      "kind": "single",
      "options":
          options ??
          [
            {"id": "a", "label": "A"},
          ],
    };

    Future<({String text, bool isError})> send({required List<Map<String, Object?>> sections, String? title}) =>
        call(tool: "send_page", arguments: {"title": title ?? "Release plan", "sections": sections});

    test("stores the page with copied images and their sizes", () async {
      final shot = png("shot.png");

      final result = await call(
        tool: "send_page",
        arguments: {
          "title": "Release plan",
          "intro": "Two choices.",
          "sections": [
            {
              "heading": "Scope",
              "images": [
                {"path": shot, "caption": "Now"},
              ],
              "questions": [
                {
                  "id": "q1",
                  "title": "Ship when?",
                  "kind": "single",
                  "required": true,
                  "options": [
                    {
                      "id": "now",
                      "label": "Now",
                      "recommended": true,
                      "image": {"path": shot},
                    },
                    {"id": "later", "label": "Later", "description": "Next week"},
                  ],
                },
                {"id": "q2", "title": "Anything else?", "kind": "text"},
              ],
            },
          ],
        },
      );

      expect(result, (
        text: "Sent “Release plan” to the user. Sesori will message this session with their answer.",
        isError: false,
      ));
      final [page] = await pages.pendingPages(sessionId: "s1");
      expect(page.sessionId, "s1");
      expect(page.displaySessionId, isNull);
      expect(page.intro, "Two choices.");
      final [section] = page.sections;
      final [image] = section.images;
      expect(image.path, isNot(shot));
      expect(File(image.path).readAsBytesSync(), File(shot).readAsBytesSync());
      expect((image.width, image.height, image.caption), (3, 2, "Now"));
      final [first, second] = section.questions;
      expect(first.isRequired, isTrue);
      final options = switch (first.kind) {
        PageSingleChoice(:final options) => options,
        _ => fail("q1 is not a single choice"),
      };
      expect(options.first.recommended, isTrue);
      expect(options.first.image?.path, image.path, reason: "one copy per distinct image");
      expect(options.last.description, "Next week");
      expect(second.kind, const PageQuestionKind.text());
      expect(second.isRequired, isFalse);
    });

    test("reads the empty fields a strict-schema model fills in as left out", () async {
      final shot = png("shot.png");
      const noImage = {"path": "", "caption": ""};

      // The arguments Claude Code, Pi and GitHub Copilot sent in the live check.
      final result = await call(
        tool: "send_page",
        arguments: {
          "title": "Fixture page",
          "intro": "",
          "sections": [
            {
              "heading": "Overview",
              "body": "",
              "images": [
                {"path": shot, "caption": "Fixture gradient"},
                noImage,
              ],
              "questions": <Object?>[],
            },
            {
              "heading": "",
              "body": "",
              "images": [noImage],
              "questions": [
                {
                  "id": "color",
                  "title": "Pick one color",
                  "body": "",
                  "images": [noImage],
                  "kind": "single",
                  "options": [
                    {"id": "red", "label": "Red", "description": "", "image": noImage, "recommended": false},
                    {"id": "green", "label": "Green", "description": "", "image": noImage, "recommended": true},
                  ],
                  "required": true,
                },
                {
                  "id": "notes",
                  "title": "Anything else?",
                  "body": "",
                  "images": <Object?>[],
                  "kind": "text",
                  "options": <Object?>[],
                  "required": false,
                },
              ],
            },
          ],
        },
      );

      expect(result.isError, isFalse, reason: result.text);
      final [page] = await pages.pendingPages(sessionId: "s1");
      expect(page.intro, isNull);
      final [overview, choices] = page.sections;
      expect(overview.images.map((image) => image.caption), ["Fixture gradient"]);
      expect((choices.heading, choices.body), (null, null));
      expect(choices.images, isEmpty);
      final [color, notes] = choices.questions;
      expect(color.body, isNull);
      expect(color.images, isEmpty);
      final options = switch (color.kind) {
        PageSingleChoice(:final options) => options,
        _ => fail("color is not a single choice"),
      };
      expect(options.map((option) => (option.description, option.image, option.recommended)), [
        (null, null, false),
        (null, null, true),
      ]);
      expect(notes.kind, const PageQuestionKind.text());
    });

    test("refuses a page over a limit and stores nothing", () async {
      final results = [
        await send(title: "x" * 201, sections: []),
        await send(
          sections: [
            {
              "images": [
                for (var index = 0; index < 21; index++) {"path": png("i$index.png")},
              ],
            },
          ],
        ),
        await send(
          sections: [
            {
              "questions": [for (var index = 0; index < 51; index++) choice("q$index")],
            },
          ],
        ),
        await send(
          sections: [
            {
              "questions": [
                choice(
                  "q1",
                  options: [
                    for (var index = 0; index < 13; index++) {"id": "o$index", "label": "O$index"},
                  ],
                ),
              ],
            },
          ],
        ),
        await send(
          sections: [
            {
              "questions": [choice("q1")],
            },
            {
              "questions": [choice("q1")],
            },
          ],
        ),
        await send(
          sections: [
            {
              "questions": [
                choice(
                  "q1",
                  options: [
                    {"id": "a", "label": "A"},
                    {"id": "a", "label": "B"},
                  ],
                ),
              ],
            },
          ],
        ),
        await send(
          sections: [
            {
              "images": [
                for (var index = 0; index < 3; index++) {"path": png("big$index.png", padding: 17 * 1024 * 1024)},
              ],
            },
          ],
        ),
      ];

      expect(results.map((result) => result.text), [
        "title is longer than 200 characters.",
        "The page has more than 20 images.",
        "The page has more than 50 questions.",
        "Question q1 has more than 12 options.",
        "Two questions have the id q1.",
        "Question q1 has two options with the id a.",
        "The page's images are over 50 MiB together.",
      ]);
      expect(results.every((result) => result.isError), isTrue);
      expect(await pages.pendingPages(sessionId: "s1"), isEmpty);
    });

    test("names the image it cannot show", () async {
      File("${files.path}/fake.png").writeAsStringSync("not a png");
      File("${files.path}/notes.txt").writeAsStringSync("text");
      File("${files.path}/huge.png").writeAsBytesSync(List.filled(maxTranscriptImageBytes + 1, 0));
      Future<String> withImage(String path) async => (await send(
        sections: [
          {
            "images": [
              {"path": path},
            ],
          },
        ],
      )).text;

      expect(await withImage("shot.png"), "Image path shot.png is not absolute.");
      expect(await withImage("${files.path}/gone.png"), "No file at image path ${files.path}/gone.png.");
      expect(
        await withImage("${files.path}/fake.png"),
        "The file at ${files.path}/fake.png is not a png, jpg, gif or webp image.",
      );
      expect(
        await withImage("${files.path}/notes.txt"),
        "The file at ${files.path}/notes.txt is not a png, jpg, gif or webp image.",
      );
      expect(await withImage("${files.path}/huge.png"), "The image at ${files.path}/huge.png is over 20 MiB.");
      expect(await pages.pendingPages(sessionId: "s1"), isEmpty);
    });

    test("names the argument a malformed page gets wrong", () async {
      Future<String> withQuestion(Map<String, Object?> question) async => (await send(
        sections: [
          {
            "questions": [question],
          },
        ],
      )).text;

      expect(
        (await call(tool: "send_page", arguments: {"sections": []})).text,
        contains("title is required"),
      );
      expect(
        await withQuestion({"id": "q1", "title": "Pick", "kind": "single", "colour": "red"}),
        contains("sections[].questions[].colour is not an argument"),
      );
      expect(
        await withQuestion({"id": "q1", "kind": "text"}),
        contains("sections[].questions[].title is required"),
      );
      expect(
        (await send(
          sections: [
            {"heading": "Scope", "colour": "red"},
          ],
        )).text,
        contains("sections[].colour is not an argument"),
      );
      expect(
        await withQuestion({
          "id": "q1",
          "title": "Pick",
          "kind": "single",
          "options": [
            {"id": "a", "label": "A", "colour": "red"},
          ],
        }),
        contains("sections[].questions[].options[].colour is not an argument"),
      );
      expect(
        (await send(
          sections: [
            {
              "images": [
                {"caption": "Now"},
              ],
            },
          ],
        )).text,
        contains("images[].path is required"),
      );
      expect(
        await withQuestion({"id": "q1", "title": "Pick", "kind": "single"}),
        contains("sections[0].questions[0].options is required when its kind is single."),
      );
      expect(
        await withQuestion({
          "id": "q1",
          "title": "Say",
          "kind": "text",
          "options": [
            {"id": "a", "label": "A"},
          ],
        }),
        contains("sections[0].questions[0].options are only for single and multiple questions."),
      );
      expect(
        await withQuestion({
          "id": "q1",
          "title": "Pick",
          "kind": "single",
          "options": [
            {"id": "a", "label": ""},
          ],
        }),
        contains("sections[0].questions[0].options[0].label is required."),
      );
      expect(
        await withQuestion({
          "id": "q1",
          "title": "Pick",
          "kind": "single",
          "options": [
            {
              "id": "a",
              "label": "A",
              "image": {"path": "", "caption": "Now"},
            },
          ],
        }),
        contains("sections[0].questions[0].options[0].image.path is required."),
        reason: "a caption says the agent meant an image",
      );
      expect(await pages.pendingPages(sessionId: "s1"), isEmpty);
    });
  });

  group("wake-ups", () {
    Future<void> addSession({required String sessionId, required String? parentSessionId}) async {
      await insertTestSession(
        db: db,
        sessionId: sessionId,
        backendSessionId: "backend-$sessionId",
        pluginId: "fake",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
      if (parentSessionId != null) {
        await db.customStatement("UPDATE sessions_table SET parent_session_id = ? WHERE session_id = ?", [
          parentSessionId,
          sessionId,
        ]);
      }
    }

    String tokenFor({required String sessionId}) {
      final minted = grants.mint(pluginId: "fake", groups: SesoriToolGroupIds.all.toSet());
      grants.bind(token: minted, backendSessionId: "backend-$sessionId");
      return minted;
    }

    test("a one-time wake-up is stored for the session and tells the agent to end its turn", () async {
      final result = await call(
        tool: "schedule_wakeup",
        arguments: {
          "label": "Check  the\nbuild",
          "prompt": "Look at CI",
          // A strict-schema provider fills every field.
          "when": {"kind": "in", "minutes": 30, "time": "", "days": <String>[]},
          "time_zone": "",
        },
      );

      expect(result.isError, isFalse, reason: result.text);
      expect(result.text, contains("End your turn now"));
      final stored = (await wakeUps.forSession(sessionId: "s1")).single;
      expect(stored.label, "Check the build");
      expect(stored.prompt, "Look at CI");
      expect(stored.nextDueAt, DateTime.utc(2026, 11, 15, 10, 30));
      expect(result.text, contains(stored.id));
    });

    test("a calendar wake-up uses the bridge computer's zone unless the agent names one", () async {
      final daily = await call(
        tool: "schedule_wakeup",
        arguments: {
          "label": "Standup",
          "prompt": "Summarize",
          "when": {"kind": "daily", "time": "09:00"},
        },
      );
      final weekly = await call(
        tool: "schedule_wakeup",
        arguments: {
          "label": "Review",
          "prompt": "Review PRs",
          "when": {
            "kind": "weekly",
            "days": ["monday"],
            "time": "08:00",
          },
          "time_zone": "America/New_York",
        },
      );

      expect(daily.isError, isFalse, reason: daily.text);
      expect(weekly.isError, isFalse, reason: weekly.text);
      expect(daily.text, contains("It repeats"));
      final listed = await call(tool: "list_wakeups", arguments: {});
      expect(listed.text, contains("Europe/Bucharest"));
      expect(listed.text, contains("America/New_York"));
      final byLabel = {for (final wakeUp in await wakeUps.forSession(sessionId: "s1")) wakeUp.label: wakeUp};
      // 09:00 in Bucharest (UTC+2) on the 16th, as 09:00 had passed on the 15th.
      expect(byLabel["Standup"]?.nextDueAt, DateTime.utc(2026, 11, 16, 7));
      // Monday the 16th, 08:00 in New York (UTC-5).
      expect(byLabel["Review"]?.nextDueAt, DateTime.utc(2026, 11, 16, 13));
    });

    test("bad wake-up arguments are refused with the field to fix", () async {
      Future<String> refused({
        required Map<String, Object?> when,
        required String? timeZone,
        required String label,
      }) async {
        final result = await call(
          tool: "schedule_wakeup",
          arguments: {"label": label, "prompt": "Prompt", "when": when, "time_zone": ?timeZone},
        );
        expect(result.isError, isTrue, reason: result.text);
        return result.text;
      }

      Future<String> refusedWhen(Map<String, Object?> when) => refused(when: when, timeZone: null, label: "Label");

      expect(await refusedWhen({"kind": "daily", "time": "25:00"}), contains("when.time must be HH:MM"));
      expect(await refusedWhen({"kind": "weekly", "time": "08:00"}), contains("when.days is required"));
      expect(await refusedWhen({"kind": "weekly", "days": <String>[], "time": "08:00"}), contains("at least one day"));
      expect(await refusedWhen({"kind": "in", "minutes": 0}), contains("when.minutes must be 1 to"));
      expect(await refusedWhen({"kind": "every", "minutes": 10081}), contains("when.minutes must be 1 to"));
      expect(await refusedWhen({"kind": "soon"}), contains("when.kind must be one of"));
      expect(
        await refused(when: {"kind": "daily", "time": "09:00"}, timeZone: "Mars/Olympus", label: "Label"),
        contains("Unknown time_zone"),
      );
      expect(
        await refused(when: {"kind": "in", "minutes": 5}, timeZone: null, label: "x" * 101),
        contains("label is longer than"),
      );
      expect(await wakeUps.forSession(sessionId: "s1"), isEmpty);
    });

    group("with a command", () {
      Future<({String text, bool isError})> scheduleCommand() => call(
        tool: "schedule_wakeup",
        arguments: {
          "label": "Tests",
          "prompt": "Read the result",
          "when": {"kind": "in", "minutes": 30},
          "command": "dart test",
        },
      );

      test("asks the user first, and their Allow stores it", () async {
        final result = await scheduleCommand();

        expect(result.isError, isFalse, reason: result.text);
        expect(result.text, contains("Sent to the user for approval"));
        expect(await wakeUps.forSession(sessionId: "s1"), isEmpty);
        final asked = approvalEvents.whereType<AgentApprovalAsked>().single.permission;
        expect(asked.sessionID, "s1");
        expect(asked.description, contains("dart test"));

        expect(await agent.settle(requestId: asked.id, reply: PermissionReply.once), isA<WakeUpCommandAnswered>());
        final stored = (await wakeUps.forSession(sessionId: "s1")).single;
        expect(stored.command?.command, "dart test");
        expect(stored.command?.approval, WakeUpCommandApproval.allowed);
        await pumpEventQueue();
        expect(notices.delivered.single.notice.summary, contains("You allowed the wake-up"));
      });

      test("is stored at once while the session approves everything", () async {
        autoApproval.yoloSessionIds.add("s1");

        final result = await scheduleCommand();

        expect(result.isError, isFalse, reason: result.text);
        expect(result.text, contains("runs the command"));
        expect(approvalEvents, isEmpty);
        final stored = (await wakeUps.forSession(sessionId: "s1")).single;
        expect(stored.command?.approval, WakeUpCommandApproval.byMode);
        expect((await call(tool: "list_wakeups", arguments: {})).text, contains("runs a command first"));
      });
    });

    test("a sub-agent's wake-up belongs to its root session, which lists and cancels it", () async {
      await addSession(sessionId: "s2", parentSessionId: "s1");
      final child = tokenFor(sessionId: "s2");

      final set = await call(
        tool: "schedule_wakeup",
        arguments: {
          "label": "Later",
          "prompt": "Continue",
          "when": {"kind": "every", "minutes": 15},
        },
        bearer: child,
      );
      expect(set.isError, isFalse, reason: set.text);
      final stored = (await wakeUps.forSession(sessionId: "s1")).single;
      expect((await call(tool: "list_wakeups", arguments: {})).text, contains(stored.id));
      expect((await call(tool: "list_wakeups", arguments: {}, bearer: child)).text, contains(stored.id));

      final cancelled = await call(tool: "cancel_wakeup", arguments: {"wakeup_id": stored.id});
      expect(cancelled.isError, isFalse, reason: cancelled.text);
      expect(await wakeUps.forSession(sessionId: "s1"), isEmpty);
      expect((await call(tool: "list_wakeups", arguments: {})).text, "This session has no wake-ups.");
    });

    test("a session cannot cancel another session's wake-up", () async {
      await addSession(sessionId: "s9", parentSessionId: null);
      final other = tokenFor(sessionId: "s9");
      await call(
        tool: "schedule_wakeup",
        arguments: {
          "label": "Theirs",
          "prompt": "Prompt",
          "when": {"kind": "in", "minutes": 5},
        },
        bearer: other,
      );
      final theirs = (await wakeUps.forSession(sessionId: "s9")).single;

      final cancelled = await call(tool: "cancel_wakeup", arguments: {"wakeup_id": theirs.id});

      expect(cancelled.isError, isTrue);
      expect(cancelled.text, contains("no wake-up ${theirs.id}"));
      expect(await wakeUps.exists(id: theirs.id), isTrue);
      expect((await call(tool: "list_wakeups", arguments: {})).text, "This session has no wake-ups.");
    });
  });

  test("the user's reply to a tool group's request reaches the group waiting on it", () async {
    final outcome = toolGroupApprovals.request(
      groupId: const SesoriToolGroupId("pr_monitor"),
      sessionId: "s1",
      title: "Sesori: PR monitor auto-merge",
      body: "Turn auto-merge on for every repository?",
    );
    await pumpEventQueue();
    final asked = approvalEvents.whereType<AgentApprovalAsked>().single.permission;
    expect(asked.tool, "Sesori: PR monitor auto-merge");

    expect(await agent.settle(requestId: asked.id, reply: PermissionReply.once), isA<ToolGroupChangeAnswered>());
    expect(await outcome, SesoriToolApprovalOutcome.allowed);
    expect(notices.delivered, isEmpty, reason: "the group tells the session itself");
  });
}

/// Records the tasks run now instead of starting sessions.
class _FakeRunService() implements ScheduledTaskRunService {
  final List<String> ranNow = [];
  ScheduledTaskRunOutcome outcome = const ScheduledTaskRunOutcome.started(session: null, late: false);

  /// The models the harness offers; null offers every model.
  Set<PromptModel>? offeredModels;

  @override
  Future<bool> offersModel({
    required ScheduledTaskDefinition definition,
    required PromptModel model,
    required String context,
  }) async => offeredModels?.contains(model) ?? true;

  @override
  Future<ScheduledTaskRun> runNow({required String taskId}) async {
    ranNow.add(taskId);
    return ScheduledTaskRun(
      id: "run-now",
      scheduledFor: const ScheduledTaskInstant(at: 0, offsetMinutes: 0),
      outcome: outcome,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

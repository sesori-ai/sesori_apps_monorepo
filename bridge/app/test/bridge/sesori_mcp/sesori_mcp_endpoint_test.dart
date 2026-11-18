import "dart:convert";
import "dart:io";
import "dart:math";

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/daos/scheduled_task_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/models/archived_session_file_dto.dart";
import "package:sesori_bridge/src/foundation/sesori_mcp_server.dart";
import "package:sesori_bridge/src/repositories/agent_approval_repository.dart";
import "package:sesori_bridge/src/repositories/models/agent_approval.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/scheduled_task_repository.dart";
import "package:sesori_bridge/src/repositories/sesori_mcp_grant_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/sesori_mcp_request_dispatcher.dart";
import "package:sesori_bridge/src/routing/sesori_mcp/sesori_mcp_result_formatter.dart";
import "package:sesori_bridge/src/services/scheduled_task_agent_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_change_description_builder.dart";
import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_bridge/src/services/scheduled_task_run_service.dart";
import "package:sesori_bridge/src/services/scheduled_task_service.dart";
import "package:sesori_bridge/src/services/sesori_mcp_access_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/fakes/fake_bridge_plugin.dart";
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
  late List<AgentApprovalEvent> approvalEvents;
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
    );
    final dispatcher = SesoriMcpRequestDispatcher(
      access: SesoriMcpAccessService(grants: grants, sessions: sessions),
      agent: agent,
      formatter: const SesoriMcpResultFormatter(),
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

    token = grants.mint(pluginId: plugin.id);
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
        ],
      );
      for (final tool in tools) {
        final name = (tool as Map<String, dynamic>)["name"] as String;
        final readOnly = name.startsWith("list_") || name.startsWith("get_");
        expect(tool["annotations"], {"readOnlyHint": readOnly});
        expect(tool["inputSchema"], containsPair("type", "object"));
      }
    });

    test("update_task asks agents to leave out the fields they are not changing", () async {
      final tools = ((await rpc(method: "tools/list", params: null))["result"] as Map<String, dynamic>)["tools"];
      Map<String, dynamic> tool(String name) =>
          (tools as List<dynamic>).cast<Map<String, dynamic>>().singleWhere((tool) => tool["name"] == name);
      Map<String, dynamic> properties(String name) =>
          (tool(name)["inputSchema"] as Map<String, dynamic>)["properties"] as Map<String, dynamic>;
      const hint = "Leave out every field you are not changing; left-out fields keep their value.";
      const settings = ["schedule", "time_zone", "missed_run_policy", "run_mode", "model", "effort", "approval_mode"];

      expect(tool("update_task")["description"], contains(hint));
      for (final setting in settings) {
        expect((properties("update_task")[setting] as Map<String, dynamic>)["description"], endsWith(hint));
        expect((properties("create_task")[setting] as Map<String, dynamic>)["description"], isNot(contains(hint)));
      }
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
      final stale = oldBridge.mint(pluginId: "fake");
      oldBridge.bind(token: stale, backendSessionId: "backend-s1");

      final response = await post(bearer: stale, message: {"jsonrpc": "2.0", "id": 1, "method": "tools/list"});

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test("a launch not yet bound can connect but no tool answers it", () async {
      final unbound = grants.mint(pluginId: "fake");

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
        expect(text.length, lessThan(SesoriMcpResultFormatter.transcriptPageChars + 1000));
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
      expect(result.text, "Sent to the user for approval. Nothing happens unless they allow it.");
      final approval = asked();
      expect(approval.sessionID, "s1");
      expect(approval.tool, "Sesori: pause task");
      expect(approval.allowAlways, isFalse);
      expect(
        approval.description,
        "Project: repo\n\n**Pause “Morning summary”**\n\nAsked by a scheduled run of this task.",
      );
      expect((await tasks.list()).items.single.enabled, isTrue);

      expect(await agent.settle(requestId: approval.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect((await tasks.list()).items.single.enabled, isFalse);
      expect(agent.pendingPermissions(sessionId: "s1"), isEmpty);
    });

    test("update_task asks the user and Allow applies it", () async {
      final result = await call(
        tool: "update_task",
        arguments: {"task_id": taskId, "prompt": "Summarize the week", "approval_mode": "approveAll"},
      );

      expect(result.isError, isFalse);
      expect(result.text, "Sent to the user for approval. If they allow it, it applies to the next run.");
      final approval = asked();
      expect(approval.tool, "Sesori: update task");
      expect(approval.description, startsWith("**Turns on Approve everything"));
      expect((await tasks.list()).items.single.definition.approvalMode, TaskApprovalMode.ask);

      expect(await agent.settle(requestId: approval.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
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
      expect(await agent.settle(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
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
        "Project: repo\n\n**Update “Morning summary”**\n\nNew prompt:\n\n```\nSummarize the week\n```\n\n"
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
        await tasks.update(taskId: taskId, definition: change(await definition()));
      }

      for (final (tool, arguments, userEdit) in [
        (
          "update_task",
          {"task_id": taskId, "name": "Evening summary"},
          () => edit((definition) => definition.copyWith(name: "Night summary")),
        ),
        ("pause_task", {"task_id": taskId}, () => tasks.setEnabled(taskId: taskId, enabled: false)),
        (
          "run_task_now",
          {"task_id": taskId},
          () => edit((definition) => definition.copyWith(approvalMode: TaskApprovalMode.approveAll)),
        ),
      ]) {
        await tasks.setEnabled(taskId: taskId, enabled: true);
        await edit((definition) => definition.copyWith(approvalMode: TaskApprovalMode.ask));
        expect(
          (await call(tool: tool, arguments: arguments)).isError,
          isFalse,
          reason: tool,
        );
        await userEdit();

        expect(
          await agent.settle(requestId: asked().id, reply: PermissionReply.once),
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
      expect(await agent.settle(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect((await tasks.list()).items.single.enabled, isFalse);
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
      );

      expect(await agent.settle(requestId: pause.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await agent.settle(requestId: edit.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());

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

      expect(await agent.settle(requestId: approveAll.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await agent.settle(requestId: edit.id, reply: PermissionReply.once), isA<AgentApprovalStale>());
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
      );

      expect(await agent.settle(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect((await tasks.list()).items.single.definition.timeZone, "Europe/Bucharest");
    });

    test("Allow applies nothing once the task is deleted", () async {
      await call(tool: "pause_task", arguments: {"task_id": taskId});
      await tasks.delete(taskId: taskId);

      expect(await agent.settle(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalStale>());
    });

    test("run_task_now runs the task on Allow, and Reject drops a request", () async {
      await call(tool: "run_task_now", arguments: {"task_id": taskId});
      expect(await agent.settle(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(runner.ranNow, [taskId]);

      runner.outcome = const ScheduledTaskRunOutcome.failed(reason: TaskRunFailureReason.projectMissing, attempt: null);
      await call(tool: "run_task_now", arguments: {"task_id": taskId});
      expect(
        await agent.settle(requestId: asked().id, reply: PermissionReply.once),
        isA<AgentApprovalRunNotStarted>(),
      );

      await call(tool: "pause_task", arguments: {"task_id": taskId});
      expect(await agent.settle(requestId: asked().id, reply: PermissionReply.reject), isA<AgentApprovalRejected>());
      expect((await tasks.list()).items.single.enabled, isTrue);
    });

    test("several requests wait on one session and each is answered on its own", () async {
      for (final pauseFirst in [true, false]) {
        await tasks.setEnabled(taskId: taskId, enabled: true);
        final prompt = "Summarize ${pauseFirst ? "the week" : "the month"}";
        await call(tool: "pause_task", arguments: {"task_id": taskId});
        final pause = asked();
        final result = await call(tool: "update_task", arguments: {"task_id": taskId, "prompt": prompt});
        final edit = asked();

        expect(result.text, "Sent to the user for approval. If they allow it, it applies to the next run.");
        expect(agent.pendingPermissions(sessionId: "s1").map((permission) => permission.id), [pause.id, edit.id]);
        for (final request in pauseFirst ? [pause, edit] : [edit, pause]) {
          expect(
            await agent.settle(requestId: request.id, reply: PermissionReply.once),
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

      expect(await agent.settle(requestId: first.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await agent.settle(requestId: second.id, reply: PermissionReply.once), isA<AgentApprovalStale>());
      expect(await agent.settle(requestId: firstPause.id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      expect(await agent.settle(requestId: secondPause.id, reply: PermissionReply.once), isA<AgentApprovalStale>());
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

      expect(await agent.settle(requestId: asked().id, reply: PermissionReply.once), isA<AgentApprovalApplied>());
      final created = (await tasks.list()).items
          .map((task) => task.definition)
          .singleWhere((definition) => definition.name == "Weekly cleanup");
      expect(created.projectId, "/repo");
      expect(created.pluginId, "fake");
      expect(created.model, const PromptModel(providerID: "anthropic", modelID: "claude-sonnet"));
      expect(created.dedicatedWorktree, isFalse);
      expect(created.approvalMode, TaskApprovalMode.ask);
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
      final grandchild = grants.mint(pluginId: "fake");
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

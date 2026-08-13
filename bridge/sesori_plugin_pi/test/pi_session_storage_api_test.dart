import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel;
import "package:test/test.dart";

void main() {
  group("root resolution", () {
    test("scans default, configured, environment, and known-directory roots", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final environmentRoot = fixture.directory("environment-sessions");
      final globalRoot = fixture.directory("global-sessions");
      final projectRoot = fixture.directory(p.join("project", "project-sessions"));
      final defaultRoot = fixture.directory(p.join("agent", "sessions", "--default--"));
      File(p.join(fixture.agentDirectory, "settings.json")).writeAsStringSync(
        jsonEncode({"sessionDir": globalRoot}),
      );
      fixture.directory(p.join("project", ".pi"));
      File(p.join(project, ".pi", "settings.json")).writeAsStringSync(
        jsonEncode({"sessionDir": "project-sessions"}),
      );
      fixture.writeSession(root: environmentRoot, id: "environment", cwd: project);
      fixture.writeSession(root: globalRoot, id: "global", cwd: project);
      fixture.writeSession(root: projectRoot, id: "project", cwd: project);
      fixture.writeSession(root: defaultRoot, id: "default", cwd: project);

      final sessions = await fixture
          .api(
            environment: {"PI_CODING_AGENT_SESSION_DIR": environmentRoot},
          )
          .listSessionMetadata(knownDirectories: {project});

      expect(sessions.map((session) => session.id), containsAll(["environment", "global", "project", "default"]));
    });

    test("uses home resolver for default agent directory", () async {
      final fixture = _StorageFixture(useExplicitAgentDirectory: false);
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory(p.join("home", ".pi", "agent", "sessions", "--project--"));
      fixture.writeSession(root: root, id: "home-default", cwd: project);

      final sessions = await fixture.api().listSessionMetadata(knownDirectories: {project});

      expect(sessions.single.id, "home-default");
    });

    test("resolves relative agent and session directories from Pi process cwd", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory(p.join("project", "relative-sessions"));
      fixture.writeSession(root: root, id: "relative", cwd: project);

      final sessions = await fixture
          .api(
            environment: {
              "PI_CODING_AGENT_DIR": "relative-agent",
              "PI_CODING_AGENT_SESSION_DIR": "relative-sessions",
            },
          )
          .listSessionMetadata(knownDirectories: {project});

      expect(sessions.single.id, "relative");
    });

    test("effective directory follows env, project, global, default precedence", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      fixture.directory(p.join("project", ".pi"));
      final projectSettings = File(p.join(project, ".pi", "settings.json"));
      final globalSettings = File(p.join(fixture.agentDirectory, "settings.json"));
      projectSettings.writeAsStringSync(jsonEncode({"sessionDir": "project-store"}));
      globalSettings.writeAsStringSync(jsonEncode({"sessionDir": "global-store"}));

      expect(
        await fixture
            .api(
              environment: {"PI_CODING_AGENT_SESSION_DIR": "environment-store"},
            )
            .resolveEffectiveSessionDirectory(directory: project),
        p.join(project, "environment-store"),
      );
      expect(
        await fixture.api().resolveEffectiveSessionDirectory(directory: project),
        p.join(project, "project-store"),
      );
      projectSettings.deleteSync();
      expect(
        await fixture.api().resolveEffectiveSessionDirectory(directory: project),
        p.join(project, "global-store"),
      );
      projectSettings.writeAsStringSync(jsonEncode({"sessionDir": null}));
      expect(
        await fixture.api().resolveEffectiveSessionDirectory(directory: project),
        _defaultSessionDirectory(agentDirectory: fixture.agentDirectory, cwd: project),
      );
    });

    test("deduplicates one root reached through several discovery sources", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      File(p.join(fixture.agentDirectory, "settings.json")).writeAsStringSync(jsonEncode({"sessionDir": root}));
      fixture.writeSession(root: root, id: "same-path", cwd: project);

      final sessions = await fixture
          .api(
            environment: {"PI_CODING_AGENT_SESSION_DIR": root},
          )
          .listSessionMetadata(knownDirectories: {project});

      expect(sessions.map((session) => session.id), ["same-path"]);
    });

    test("returns no default sessions when no user home resolves", () async {
      final api = PiSessionStorageApi(environment: const {});

      expect(await api.listSessionMetadata(knownDirectories: const {}), isEmpty);
      expect(await api.resolveEffectiveSessionDirectory(directory: p.current), isNull);
    });

    test("uses project-configured storage when no user home resolves", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory(p.join("project", "project-sessions"));
      fixture.directory(p.join("project", ".pi"));
      File(p.join(project, ".pi", "settings.json")).writeAsStringSync(
        jsonEncode({"sessionDir": "project-sessions"}),
      );
      fixture.writeSession(root: root, id: "project-only", cwd: project);
      final api = PiSessionStorageApi(environment: const {});

      final sessions = await api.listSessionMetadata(knownDirectories: {project});

      expect(sessions.map((session) => session.id), ["project-only"]);
      expect(await api.resolveEffectiveSessionDirectory(directory: project), root);
    });

    test("invalid project session directory falls back to global settings", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final globalRoot = fixture.directory("global-sessions");
      fixture.directory(p.join("project", ".pi"));
      File(p.join(project, ".pi", "settings.json")).writeAsStringSync(
        jsonEncode({"sessionDir": 42}),
      );
      File(p.join(fixture.agentDirectory, "settings.json")).writeAsStringSync(
        jsonEncode({"sessionDir": globalRoot}),
      );
      fixture.writeSession(root: globalRoot, id: "global-fallback", cwd: project);

      final sessions = await fixture.api().listSessionMetadata(knownDirectories: {project});

      expect(sessions.map((session) => session.id), ["global-fallback"]);
      expect(await fixture.api().resolveEffectiveSessionDirectory(directory: project), globalRoot);
    });
  });

  group("metadata scanning", () {
    test("maps header, latest explicit title, mtime, and exact path", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("deleted-project");
      Directory(project).deleteSync();
      final root = fixture.directory("sessions");
      final path = fixture.writeSession(
        root: root,
        id: "named",
        cwd: project,
        timestamp: "2026-08-01T10:00:00Z",
        entries: [
          {"type": "session_info", "name": " First "},
          {
            "type": "message",
            "message": {"content": "private prompt"},
          },
          {"type": "session_info", "name": "Latest"},
        ],
      );
      final modified = DateTime.utc(2026, 8, 2, 12, 30);
      File(path).setLastModifiedSync(modified);
      final api = fixture.api(environment: {"PI_CODING_AGENT_SESSION_DIR": root});

      final session = (await api.listSessionMetadata(knownDirectories: const {})).single;

      expect(session.id, "named");
      expect(session.cwd, p.normalize(p.absolute(project)));
      expect(session.title, "Latest");
      expect(session.createdAt, DateTime.utc(2026, 8, 1, 10));
      expect(session.updatedAt, modified);
      expect(
        await api.resolveSessionPath(sessionId: "named", knownDirectories: const {}),
        File(path).resolveSymbolicLinksSync(),
      );
      expect(await api.resolveSessionPath(sessionId: "missing", knownDirectories: const {}), isNull);
    });

    test("latest empty title explicitly clears an earlier title", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      fixture.writeSession(
        root: root,
        id: "cleared",
        cwd: project,
        entries: [
          {"type": "session_info", "name": "Before"},
          {"type": "session_info", "name": "  "},
        ],
      );

      final session =
          (await fixture
                  .api(
                    environment: {"PI_CODING_AGENT_SESSION_DIR": root},
                  )
                  .listSessionMetadata(knownDirectories: const {}))
              .single;

      expect(session.title, isNull);
    });

    test("skips a malformed title record without clearing the prior title", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      fixture.writeSession(
        root: root,
        id: "malformed-title",
        cwd: project,
        entries: [
          {"type": "session_info", "name": "Retained"},
          {"type": "session_info", "name": 42},
        ],
      );

      final session =
          (await fixture
                  .api(
                    environment: {"PI_CODING_AGENT_SESSION_DIR": root},
                  )
                  .listSessionMetadata(knownDirectories: const {}))
              .single;

      expect(session.title, "Retained");
    });

    test("skips malformed headers and tolerates a half-written final record", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      File(p.join(root, "malformed.jsonl")).writeAsStringSync('{"type":"session","id":}\n');
      final valid = fixture.writeSession(
        root: root,
        id: "valid",
        cwd: project,
        entries: [
          {"type": "session_info", "name": "Retained"},
        ],
      );
      File(valid).writeAsStringSync('{"type":"session_info","name":', mode: FileMode.append);

      final warnings = await _captureWarnings(() async {
        final sessions = await fixture
            .api(
              environment: {"PI_CODING_AGENT_SESSION_DIR": root},
            )
            .listSessionMetadata(knownDirectories: const {});
        expect(sessions.map((session) => session.id), ["valid"]);
        expect(sessions.single.title, "Retained");
      });

      expect(warnings, contains("malformed session metadata"));
      expect(warnings, isNot(contains(project)));
    });

    test("discards oversized message payloads without losing later metadata", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      final file = fixture.writeSession(root: root, id: "large-message", cwd: project);
      File(file).writeAsStringSync(
        '${jsonEncode({
          "type": "message",
          "message": {"content": "private${"x" * (PiSessionStorageApi.metadataRecordByteLimit + 100)}"},
        })}\n'
        '${jsonEncode({"type": "session_info", "name": "After"})}\n',
        mode: FileMode.append,
      );

      final session =
          (await fixture
                  .api(
                    environment: {"PI_CODING_AGENT_SESSION_DIR": root},
                  )
                  .listSessionMetadata(knownDirectories: const {}))
              .single;

      expect(session.title, "After");
    });

    test("bounds oversized metadata and never logs source or paths", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("private-project");
      final root = fixture.directory("private-sessions");
      final file = fixture.writeSession(root: root, id: "bounded", cwd: project);
      final secret = "private-title-${"x" * PiSessionStorageApi.metadataRecordByteLimit}";
      File(file).writeAsStringSync('${jsonEncode({"type": "session_info", "name": secret})}\n', mode: FileMode.append);

      final warnings = await _captureWarnings(() async {
        final session =
            (await fixture
                    .api(
                      environment: {"PI_CODING_AGENT_SESSION_DIR": root},
                    )
                    .listSessionMetadata(knownDirectories: const {}))
                .single;
        expect(session.title, isNull);
      });

      expect(warnings, contains("oversized session metadata"));
      expect(warnings, isNot(contains(secret.substring(0, 20))));
      expect(warnings, isNot(contains(root)));
      expect(warnings, isNot(contains(project)));
    });

    test("uses only a first-key type discriminator", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      File(p.join(root, "not-pi.jsonl")).writeAsStringSync(
        '${jsonEncode({"id": "foreign", "type": "session", "cwd": project})}\n',
      );
      fixture.writeSession(root: root, id: "pi", cwd: project);

      final sessions = await fixture
          .api(
            environment: {"PI_CODING_AGENT_SESSION_DIR": root},
          )
          .listSessionMetadata(knownDirectories: const {});

      expect(sessions.map((session) => session.id), ["pi"]);
    });

    test("throws when distinct exact files declare one session id", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final first = fixture.directory("first");
      final second = fixture.directory("second");
      fixture.writeSession(root: first, id: "duplicate", cwd: project);
      fixture.writeSession(root: second, id: "duplicate", cwd: project, fileName: "other.jsonl");
      File(p.join(fixture.agentDirectory, "settings.json")).writeAsStringSync(jsonEncode({"sessionDir": second}));

      expect(
        fixture
            .api(
              environment: {"PI_CODING_AGENT_SESSION_DIR": first},
            )
            .listSessionMetadata(knownDirectories: {project}),
        throwsA(
          isA<PiSessionStorageConflictException>().having(
            (error) => error.sessionId,
            "sessionId",
            "duplicate",
          ),
        ),
      );
    });

    test("malformed and oversized settings fall back without logging their content", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      fixture.directory(p.join("project", ".pi"));
      final projectSettings = p.join(project, ".pi", "settings.json");
      final globalSettings = p.join(fixture.agentDirectory, "settings.json");
      File(projectSettings).writeAsStringSync('{"private-setting":');
      File(globalSettings).writeAsStringSync("x" * (PiSessionStorageApi.settingsByteLimit + 1));

      final warnings = await _captureWarnings(() async {
        expect(
          await fixture.api().resolveEffectiveSessionDirectory(directory: project),
          _defaultSessionDirectory(agentDirectory: fixture.agentDirectory, cwd: project),
        );
      });

      expect(warnings, contains("malformed session settings"));
      expect(warnings, contains(projectSettings));
      expect(warnings, contains("oversized session settings"));
      expect(warnings, contains(globalSettings));
      expect(warnings, isNot(contains("private-setting")));
    });
  });

  group("lineage and symlinks", () {
    test("maps parent path to header id and imports an external parent", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      final external = fixture.directory("external");
      final parentPath = fixture.writeSession(
        root: external,
        id: "parent-id",
        cwd: project,
        fileName: "misleading-name.jsonl",
      );
      fixture.writeSession(
        root: root,
        id: "child-id",
        cwd: project,
        parentSession: parentPath,
      );

      final sessions = await fixture
          .api(
            environment: {"PI_CODING_AGENT_SESSION_DIR": root},
          )
          .listSessionMetadata(knownDirectories: const {});
      final byId = {for (final session in sessions) session.id: session};

      expect(byId.keys, containsAll(["parent-id", "child-id"]));
      expect(byId["child-id"]?.parentId, "parent-id");
      expect(byId["parent-id"]?.parentId, isNull);
    });

    test("leaves an unresolvable parent private path unattributed", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      fixture.writeSession(
        root: root,
        id: "orphan",
        cwd: project,
        parentSession: p.join(fixture.root.path, "missing", "parent.jsonl"),
      );

      final session =
          (await fixture
                  .api(
                    environment: {"PI_CODING_AGENT_SESSION_DIR": root},
                  )
                  .listSessionMetadata(knownDirectories: const {}))
              .single;

      expect(session.parentId, isNull);
    });

    test("follows one session-bucket symlink without recursing through a loop", () async {
      if (Platform.isWindows) return;
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final target = fixture.directory("target");
      fixture.writeSession(root: target, id: "linked", cwd: project);
      final sessionsRoot = fixture.directory(p.join("agent", "sessions"));
      Link(p.join(sessionsRoot, "linked-bucket")).createSync(target);
      Link(p.join(sessionsRoot, "loop")).createSync(sessionsRoot);

      final sessions = await fixture.api().listSessionMetadata(knownDirectories: {project});

      expect(sessions.map((session) => session.id), ["linked"]);
    });

    test("deduplicates a physical file reached through real and symlink roots", () async {
      if (Platform.isWindows) return;
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      final path = fixture.writeSession(root: root, id: "linked-once", cwd: project);
      final linkedRoot = p.join(fixture.root.path, "linked-sessions");
      Link(linkedRoot).createSync(root);
      File(p.join(fixture.agentDirectory, "settings.json")).writeAsStringSync(jsonEncode({"sessionDir": root}));
      final api = fixture.api(environment: {"PI_CODING_AGENT_SESSION_DIR": linkedRoot});

      final sessions = await api.listSessionMetadata(knownDirectories: {project});

      expect(sessions.map((session) => session.id), ["linked-once"]);
      expect(
        await api.resolveSessionPath(sessionId: "linked-once", knownDirectories: {project}),
        File(path).resolveSymbolicLinksSync(),
      );
    });

    test("resolves a parent path through a symlink to the scanned physical file", () async {
      if (Platform.isWindows) return;
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      final parentPath = fixture.writeSession(root: root, id: "parent", cwd: project);
      final parentLink = p.join(fixture.root.path, "parent-link.jsonl");
      Link(parentLink).createSync(parentPath);
      fixture.writeSession(root: root, id: "child", cwd: project, parentSession: parentLink);

      final sessions = await fixture
          .api(
            environment: {"PI_CODING_AGENT_SESSION_DIR": root},
          )
          .listSessionMetadata(knownDirectories: const {});
      final byId = {for (final session in sessions) session.id: session};

      expect(byId.keys, containsAll(["parent", "child"]));
      expect(byId["child"]?.parentId, "parent");
    });

    test("bounds external parent traversal and reports the bound without paths", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      final external = fixture.directory("private-lineage");
      String? parentPath;
      for (var index = PiSessionStorageApi.externalParentLimit; index >= 0; index -= 1) {
        parentPath = fixture.writeSession(
          root: external,
          id: "ancestor-$index",
          cwd: project,
          parentSession: parentPath,
        );
      }
      fixture.writeSession(root: root, id: "child", cwd: project, parentSession: parentPath);

      final warnings = await _captureWarnings(() async {
        final sessions = await fixture
            .api(
              environment: {"PI_CODING_AGENT_SESSION_DIR": root},
            )
            .listSessionMetadata(knownDirectories: const {});
        expect(sessions, hasLength(PiSessionStorageApi.externalParentLimit + 1));
        expect(sessions.any((session) => session.id == "ancestor-${PiSessionStorageApi.externalParentLimit}"), isFalse);
      });

      expect(warnings, contains("metadata scan bound"));
      expect(warnings, isNot(contains(external)));
      expect(warnings, isNot(contains(project)));
    });

    test("bounds external parent header reads without logging file content", () async {
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      final external = fixture.directory("private-parent");
      final parentPath = p.join(external, "oversized-prefix.jsonl");
      const secret = "private-parent-prefix";
      File(parentPath).writeAsStringSync(
        "$secret${"x" * PiSessionStorageApi.externalParentHeaderByteLimit}\n"
        '${jsonEncode({"type": "session", "id": "parent", "cwd": project})}\n',
      );
      fixture.writeSession(root: root, id: "child", cwd: project, parentSession: parentPath);

      final warnings = await _captureWarnings(() async {
        final sessions = await fixture
            .api(
              environment: {"PI_CODING_AGENT_SESSION_DIR": root},
            )
            .listSessionMetadata(knownDirectories: const {});
        expect(sessions.map((session) => session.id), ["child"]);
        expect(sessions.single.parentId, isNull);
      });

      expect(warnings, contains("external parent session header"));
      expect(warnings, isNot(contains(parentPath)));
      expect(warnings, isNot(contains(secret)));
      expect(warnings, isNot(contains(project)));
    });

    test("logs a broken session symlink with path and cause while continuing", () async {
      if (Platform.isWindows) return;
      final fixture = _StorageFixture();
      addTearDown(fixture.dispose);
      final project = fixture.directory("project");
      final root = fixture.directory("sessions");
      final brokenPath = p.join(root, "broken.jsonl");
      Link(brokenPath).createSync(p.join(fixture.root.path, "missing.jsonl"));
      fixture.writeSession(root: root, id: "valid", cwd: project);

      final warnings = await _captureWarnings(() async {
        final sessions = await fixture
            .api(
              environment: {"PI_CODING_AGENT_SESSION_DIR": root},
            )
            .listSessionMetadata(knownDirectories: const {});
        expect(sessions.map((session) => session.id), ["valid"]);
      });

      expect(warnings, contains("resolve Pi session file"));
      expect(warnings, contains(brokenPath));
      expect(warnings, contains("FileSystemException"));
      expect(warnings, isNot(contains(project)));
    });
  });

  test("real Pi root scan retains metadata-only structural invariants when available", () async {
    final sessions = await PiSessionStorageApi(
      environment: Platform.environment,
    ).listSessionMetadata(knownDirectories: const {});

    expect(sessions.every((session) => session.id.isNotEmpty && p.isAbsolute(session.cwd)), isTrue);
    expect(sessions.map((session) => session.id).toSet(), hasLength(sessions.length));
  });
}

final class _StorageFixture({final bool useExplicitAgentDirectory = true}) {
  final Directory root = Directory.systemTemp.createTempSync("pi-session-storage-");
  late final String homeDirectory = directory("home");
  late final String agentDirectory = useExplicitAgentDirectory
      ? directory("agent")
      : directory(p.join("home", ".pi", "agent"));

  String directory(String relativePath) {
    final result = p.join(root.path, relativePath);
    Directory(result).createSync(recursive: true);
    return result;
  }

  PiSessionStorageApi api({Map<String, String> environment = const {}}) => PiSessionStorageApi(
    environment: {
      "HOME": homeDirectory,
      if (useExplicitAgentDirectory) "PI_CODING_AGENT_DIR": agentDirectory,
      ...environment,
    },
  );

  String writeSession({
    required String root,
    required String id,
    required String cwd,
    String timestamp = "2026-08-01T00:00:00Z",
    String? parentSession,
    String? fileName,
    List<Map<String, Object?>> entries = const [],
  }) {
    Directory(root).createSync(recursive: true);
    final path = p.join(root, fileName ?? "$id.jsonl");
    final records = <Map<String, Object?>>[
      {
        "type": "session",
        "version": 3,
        "id": id,
        "timestamp": timestamp,
        "cwd": cwd,
        "parentSession": parentSession,
      },
      ...entries,
    ];
    File(path).writeAsStringSync("${records.map(jsonEncode).join("\n")}\n");
    return path;
  }

  void dispose() => root.deleteSync(recursive: true);
}

String _defaultSessionDirectory({required String agentDirectory, required String cwd}) {
  final resolved = p.normalize(p.absolute(cwd));
  final stripped = resolved.startsWith(p.separator) ? resolved.substring(1) : resolved;
  return p.join(agentDirectory, "sessions", "--${stripped.replaceAll(RegExp(r"[/\\:]"), "-")}--");
}

Future<String> _captureWarnings(Future<void> Function() action) async {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    await IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

final class _BufferingStdout() implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

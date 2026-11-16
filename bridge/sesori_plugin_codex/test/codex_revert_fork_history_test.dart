import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/api/models/codex_rollout_file_name.dart";
import "package:codex_plugin/src/models/codex_replay_tool_disposition.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_session_deletion.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Rollouts recorded from codex-cli 0.167.2 app-server (paths and long
/// instruction text scrubbed): a thread answered "one", "two", "three";
/// `thread/revert {beforeTurnId: three}` and a new turn "four"; then
/// `thread/fork {lastTurnId: one}` and a fork turn "five".
const _fixtureDay = "test/fixtures/codex_revert_fork/sessions/2026/11/15";
const _sourceId = "01a1e0e9-81f9-7b81-81c6-a835c1d98756";
const _forkId = "01a1e0e9-9887-72f3-a66b-5dc982bcbbd9";
const _originalRollout = "rollout-2026-11-15T12-32-41-$_sourceId.jsonl";
const _revertRollout = "rollout-2026-11-15T12-32-46-${_sourceId}_01a1e0e9-9291-71f0-a1f7-c120823372e5.jsonl";
const _forkRollout = "rollout-2026-11-15T12-32-47-$_forkId.jsonl";

void main() {
  late Directory codexHome;
  late Directory sessionDay;
  late CodexRolloutApi rolloutApi;
  late CodexCatalogRepository catalogRepository;
  late CodexMessageRepository messageRepository;

  setUp(() {
    codexHome = Directory.systemTemp.createTempSync("codex-revert-fork-");
    sessionDay = Directory(p.join(codexHome.path, "sessions", "2026", "11", "15"))..createSync(recursive: true);
    for (final file in Directory(_fixtureDay).listSync().whereType<File>()) {
      file.copySync(p.join(sessionDay.path, p.basename(file.path)));
    }
    rolloutApi = CodexRolloutApi(environment: {"CODEX_HOME": codexHome.path});
    catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
    messageRepository = CodexMessageRepository(
      rolloutApi: rolloutApi,
      rolloutToolMapper: const CodexRolloutToolMapper(imageAttachmentMapper: CodexImageAttachmentMapper()),
      userContentMapper: const CodexUserContentMapper(),
    );
  });

  tearDown(() => codexHome.deleteSync(recursive: true));

  Future<List<PluginMessageWithParts>> readMessages({required String sessionId}) async {
    final path = await catalogRepository.findRolloutPath(sessionId: sessionId);
    if (path == null) fail("no rollout for $sessionId");
    final read = messageRepository.prepareMessageRead(rolloutPath: path, sessionId: sessionId);
    return messageRepository.projectMessages(
      read: read,
      sessionId: sessionId,
      children: const [],
      replayToolDisposition: CodexReplayToolDisposition.terminalize,
      structuredToolStatusByCallId: const {},
      childReplayDataById: const {},
      config: const CodexConfigDefaults.empty(),
    );
  }

  List<String> texts({required List<PluginMessageWithParts> messages}) => [
    for (final message in messages) ...message.parts.whereType<PluginMessagePartText>().map((part) => part.text),
  ];

  group("CodexRolloutFileName", () {
    test("parses a thread's first rollout and a reverted rollout", () {
      final first = CodexRolloutFileName.tryParse(fileName: _originalRollout);
      final reverted = CodexRolloutFileName.tryParse(fileName: _revertRollout);
      if (first == null || reverted == null) fail("fixture names must parse");
      expect(first.threadId, _sourceId);
      expect(first.rolloutId, _sourceId);
      expect(reverted.threadId, _sourceId);
      expect(reverted.rolloutId, "01a1e0e9-9291-71f0-a1f7-c120823372e5");
      expect(reverted.timestamp, "2026-11-15T12-32-46");
      expect(reverted.isNewerThan(other: first), isTrue);
      expect(first.isNewerThan(other: reverted), isFalse);
    });

    test("rejects names that are not rollouts", () {
      for (final name in [
        "rollout-2026-11-15T12-32-41-not-a-uuid.jsonl",
        "rollout-2026-11-15T12-32-41-$_sourceId.json",
        "session-2026-11-15T12-32-41-$_sourceId.jsonl",
        "rollout-$_sourceId.jsonl",
        "rollout-2026-11-15X12-32-41-$_sourceId.jsonl",
      ]) {
        expect(CodexRolloutFileName.tryParse(fileName: name), isNull, reason: name);
      }
    });
  });

  test("the catalog lists a reverted thread once, at its current rollout and original creation time", () async {
    final records = await catalogRepository.listSessionRecords();

    expect(records.map((record) => record.id), unorderedEquals([_sourceId, _forkId]));
    final source = records.singleWhere((record) => record.id == _sourceId);
    expect(p.basename(source.rolloutPath), _revertRollout);
    expect(source.createdAt, DateTime.parse("2026-11-15T20:32:41.977Z"));
    expect(source.cwd, "/workspace/demo");
    final fork = records.singleWhere((record) => record.id == _forkId);
    expect(p.basename(fork.rolloutPath), _forkRollout);
    expect(fork.parentId, isNull);
  });

  test("a reverted thread reads its kept turns and the turns after the revert", () async {
    final messages = await readMessages(sessionId: _sourceId);

    expect(texts(messages: messages), [
      "Reply with exactly the word: one",
      "one",
      "Reply with exactly the word: two",
      "two",
      "Reply with exactly the word: four",
      "four",
    ]);
  });

  test("a fork reads the source's kept turn under the source's item ids, then its own turns", () async {
    final source = await readMessages(sessionId: _sourceId);
    final fork = await readMessages(sessionId: _forkId);

    expect(texts(messages: fork), [
      "Reply with exactly the word: one",
      "one",
      "Reply with exactly the word: five",
      "five",
    ]);
    expect(
      fork.take(2).map((message) => message.info.id),
      source.take(2).map((message) => message.info.id),
    );
    expect(fork.first.info.id, "01a1e0e9-8286-7273-832d-11b2cf5b15b8");
  });

  test("history bases are found among archived rollouts", () async {
    // Index the current rollouts before the base moves.
    await catalogRepository.listSessionRecords();
    final archived = Directory(p.join(codexHome.path, "archived_sessions"))..createSync();
    File(p.join(sessionDay.path, _originalRollout)).renameSync(p.join(archived.path, _originalRollout));

    expect(texts(messages: await readMessages(sessionId: _forkId)), hasLength(4));
    expect(texts(messages: await readMessages(sessionId: _sourceId)), hasLength(6));
  });

  test("a missing history base leaves only the later history", () async {
    await catalogRepository.listSessionRecords();
    File(p.join(sessionDay.path, _originalRollout)).deleteSync();

    expect(texts(messages: await readMessages(sessionId: _sourceId)), [
      "Reply with exactly the word: four",
      "four",
    ]);
  });

  test("session activity comes from a revert rollout filed on a later day", () {
    // Tomorrow's folder: later than the fixture's day and inside the recent
    // window on any run date.
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final laterDay = Directory(
      p.join(
        codexHome.path,
        "sessions",
        tomorrow.year.toString(),
        tomorrow.month.toString().padLeft(2, "0"),
        tomorrow.day.toString().padLeft(2, "0"),
      ),
    )..createSync(recursive: true);
    final revert = File(p.join(sessionDay.path, _revertRollout)).renameSync(p.join(laterDay.path, _revertRollout));
    File(p.join(sessionDay.path, _originalRollout)).setLastModifiedSync(DateTime.utc(2026, 11, 15, 21));
    final revertModified = DateTime.utc(2026, 11, 16, 9);
    revert.setLastModifiedSync(revertModified);

    expect(
      catalogRepository.readSessionActivity(sessionId: _sourceId),
      isA<PluginSessionActivityAvailable>().having(
        (activity) => activity.updatedAt,
        "updatedAt",
        revertModified.millisecondsSinceEpoch,
      ),
    );
  });

  test("session activity of an older thread comes from its creation-date folder", () {
    final revertModified = DateTime.utc(2026, 11, 15, 22);
    File(p.join(sessionDay.path, _revertRollout)).setLastModifiedSync(revertModified);

    expect(
      catalogRepository.readSessionActivity(sessionId: _sourceId),
      isA<PluginSessionActivityAvailable>().having(
        (activity) => activity.updatedAt,
        "updatedAt",
        revertModified.millisecondsSinceEpoch,
      ),
    );
  });

  List<String> rolloutFiles() => [for (final file in sessionDay.listSync()) p.basename(file.path)]..sort();

  // An origin delete and a first-message swap's delete of the replaced
  // session both land here.
  test("deleting a forked thread keeps the rollout its fork builds on", () async {
    expect(await catalogRepository.deleteSession(sessionId: _sourceId), CodexSessionDeletion.keptForForks);

    expect(rolloutFiles(), [_originalRollout, _forkRollout]);
    expect(texts(messages: await readMessages(sessionId: _forkId)), hasLength(4));
    // A bridge restart starts from a fresh catalog.
    catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
    expect(texts(messages: await readMessages(sessionId: _forkId)), hasLength(4));
  });

  test("a fork of a deleted, archived fork keeps the rollouts it builds on through it", () async {
    // A fork of the fork, through all of the fork's history.
    const grandForkId = "01a1e0f0-0000-7000-8000-0000000000aa";
    final forkFile = File(p.join(sessionDay.path, _forkRollout));
    final meta = {
      "timestamp": "2026-11-15T20:50:00.000Z",
      "type": "session_meta",
      "payload": {
        "id": grandForkId,
        "timestamp": "2026-11-15T20:50:00.000Z",
        "cwd": "/workspace/demo",
        "history_mode": "paginated",
        "history_base": {
          "thread_id": _forkId,
          "end_ordinal_exclusive": forkFile.readAsLinesSync().length,
          "end_byte_offset": forkFile.lengthSync(),
        },
      },
    };
    File(p.join(sessionDay.path, "rollout-2026-11-15T12-50-00-$grandForkId.jsonl"))
        .writeAsStringSync("${jsonEncode(meta)}\n");

    expect(await catalogRepository.deleteSession(sessionId: _forkId), CodexSessionDeletion.keptForForks);
    // What `thread/archive` does with the kept fork; then a bridge restart.
    final archived = Directory(p.join(codexHome.path, "archived_sessions"))..createSync();
    forkFile.renameSync(p.join(archived.path, _forkRollout));
    catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);

    expect(await catalogRepository.deleteSession(sessionId: _sourceId), CodexSessionDeletion.keptForForks);
    expect(rolloutFiles(), [_originalRollout, "rollout-2026-11-15T12-50-00-$grandForkId.jsonl"]);
    expect(texts(messages: await readMessages(sessionId: grandForkId)), hasLength(4));
  });

  test("an unreadable header that may name the deleted thread keeps all its rollouts", () async {
    final fork = File(p.join(sessionDay.path, _forkRollout));
    await catalogRepository.listSessionRecords();
    Process.runSync("chmod", ["000", fork.path]);
    addTearDown(() => Process.runSync("chmod", ["644", fork.path]));
    // A fresh catalog must read the fork's header during the delete.
    catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);

    expect(await catalogRepository.deleteSession(sessionId: _sourceId), CodexSessionDeletion.keptForForks);
    expect(rolloutFiles(), [_originalRollout, _revertRollout, _forkRollout]);
  }, testOn: "posix");

  test("a thread no fork builds on deletes every rollout it owns", () async {
    expect(await catalogRepository.deleteSession(sessionId: _forkId), CodexSessionDeletion.deleted);
    expect(rolloutFiles(), [_originalRollout, _revertRollout]);

    expect(await catalogRepository.deleteSession(sessionId: _sourceId), CodexSessionDeletion.deleted);
    expect(rolloutFiles(), isEmpty);
    expect(await catalogRepository.listSessionRecords(), isEmpty);
  });

  test("a thread kept for a fork deletes its last rollout once the fork is gone", () async {
    await catalogRepository.deleteSession(sessionId: _sourceId);
    await catalogRepository.deleteSession(sessionId: _forkId);

    expect(await catalogRepository.deleteSession(sessionId: _sourceId), CodexSessionDeletion.deleted);
    expect(rolloutFiles(), isEmpty);
  });
}

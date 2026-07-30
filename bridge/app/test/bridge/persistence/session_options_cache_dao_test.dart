import "package:sesori_bridge/src/api/database/daos/session_options_cache_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/session_options_cache_table.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionOptionsCacheDao", () {
    late AppDatabase db;
    late SessionOptionsCacheDao dao;

    setUp(() {
      db = createTestDatabase();
      dao = db.sessionOptionsCacheDao;
    });

    tearDown(() async {
      await db.close();
    });

    test("reads and deletes only the exact composite key", () async {
      final cursor = _row(
        pluginId: "cursor",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "cursor",
        projectId: null,
        capturedProjectPath: null,
        revision: 1,
        capturedAt: 100,
        completeness: PluginSessionOptionsCompleteness.complete,
        agentsJson: '["cursor-agent"]',
        providersJson: '{"cursor":true}',
        commandsJson: '["cursor-command"]',
      );
      final codex = _row(
        pluginId: "codex",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "codex",
        projectId: null,
        capturedProjectPath: null,
        revision: 1,
        capturedAt: 200,
        completeness: PluginSessionOptionsCompleteness.partial,
        agentsJson: '["codex-agent"]',
        providersJson: '{"codex":true}',
        commandsJson: '["codex-command"]',
      );
      final cursorSecondaryOwner = _row(
        pluginId: "cursor",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "cursor-secondary-owner",
        projectId: null,
        capturedProjectPath: null,
        revision: 1,
        capturedAt: 300,
        completeness: PluginSessionOptionsCompleteness.complete,
        agentsJson: "[]",
        providersJson: "{}",
        commandsJson: "[]",
      );
      expect(await dao.compareAndSet(row: cursor, expectedRevision: null), isTrue);
      expect(await dao.compareAndSet(row: codex, expectedRevision: null), isTrue);
      expect(await dao.compareAndSet(row: cursorSecondaryOwner, expectedRevision: null), isTrue);

      expect(
        await dao.getRow(
          pluginId: "cursor",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "cursor",
        ),
        cursor,
      );
      expect(
        await dao.getRow(
          pluginId: "cursor",
          scope: PluginSessionOptionsScope.project,
          ownerId: "cursor",
        ),
        isNull,
      );

      await dao.deleteRow(
        pluginId: "cursor",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "cursor",
      );

      expect(
        await dao.getRow(
          pluginId: "cursor",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "cursor",
        ),
        isNull,
      );
      expect(
        await dao.getRow(
          pluginId: "cursor",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "cursor-secondary-owner",
        ),
        cursorSecondaryOwner,
      );
      expect(
        await dao.getRow(
          pluginId: "codex",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "codex",
        ),
        codex,
      );
    });

    test("commits inserts only when absent and updates only at the expected revision", () async {
      final initial = _row(
        pluginId: "opencode",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "opencode",
        projectId: null,
        capturedProjectPath: null,
        revision: 1,
        capturedAt: 100,
        completeness: PluginSessionOptionsCompleteness.partial,
        agentsJson: '["initial-agent"]',
        providersJson: '{"initial":true}',
        commandsJson: '["initial-command"]',
      );
      final updated = _row(
        pluginId: "opencode",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "opencode",
        projectId: null,
        capturedProjectPath: null,
        revision: 2,
        capturedAt: 200,
        completeness: PluginSessionOptionsCompleteness.complete,
        agentsJson: '["updated-agent"]',
        providersJson: '{"updated":true}',
        commandsJson: '["updated-command"]',
      );

      expect(await dao.compareAndSet(row: initial, expectedRevision: null), isTrue);
      expect(await dao.compareAndSet(row: updated, expectedRevision: null), isFalse);
      expect(await dao.compareAndSet(row: updated, expectedRevision: 0), isFalse);
      expect(
        await dao.getRow(
          pluginId: "opencode",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "opencode",
        ),
        initial,
      );

      expect(await dao.compareAndSet(row: updated, expectedRevision: 1), isTrue);
      expect(
        await dao.getRow(
          pluginId: "opencode",
          scope: PluginSessionOptionsScope.plugin,
          ownerId: "opencode",
        ),
        updated,
      );

      final absent = _row(
        pluginId: "cursor",
        scope: PluginSessionOptionsScope.plugin,
        ownerId: "cursor",
        projectId: null,
        capturedProjectPath: null,
        revision: 2,
        capturedAt: 300,
        completeness: PluginSessionOptionsCompleteness.complete,
        agentsJson: "[]",
        providersJson: "{}",
        commandsJson: "[]",
      );
      expect(await dao.compareAndSet(row: absent, expectedRevision: 1), isFalse);
    });
  });
}

SessionOptionsCacheDto _row({
  required String pluginId,
  required PluginSessionOptionsScope scope,
  required String ownerId,
  required String? projectId,
  required String? capturedProjectPath,
  required int revision,
  required int capturedAt,
  required PluginSessionOptionsCompleteness completeness,
  required String agentsJson,
  required String providersJson,
  required String commandsJson,
}) {
  return SessionOptionsCacheDto(
    pluginId: pluginId,
    scope: scope,
    ownerId: ownerId,
    projectId: projectId,
    capturedProjectPath: capturedProjectPath,
    revision: revision,
    capturedAt: capturedAt,
    completeness: completeness,
    agentsJson: agentsJson,
    providersJson: providersJson,
    commandsJson: commandsJson,
  );
}

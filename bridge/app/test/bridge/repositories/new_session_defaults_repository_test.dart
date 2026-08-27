import "package:sesori_bridge/src/api/database/daos/new_session_defaults_dao.dart";
import "package:sesori_bridge/src/repositories/new_session_defaults_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  test("stores and replaces new-session defaults independently per plugin", () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = NewSessionDefaultsRepository(
      dao: NewSessionDefaultsDao(database: database),
    );

    await repository.write(
      pluginId: "plugin-a",
      defaults: const SessionPromptDefaults(
        agent: "build",
        model: AgentModel(providerID: "provider-a", modelID: "model-a", variant: "high"),
      ),
    );
    await repository.write(
      pluginId: "plugin-b",
      defaults: const SessionPromptDefaults(
        agent: "review",
        model: AgentModel(providerID: "provider-b", modelID: "model-b", variant: "low"),
      ),
    );
    await repository.write(
      pluginId: "plugin-a",
      defaults: const SessionPromptDefaults(
        agent: "plan",
        model: AgentModel(providerID: "provider-a", modelID: "model-c", variant: "xhigh"),
      ),
    );

    expect(
      await repository.read(pluginId: "plugin-a"),
      const SessionPromptDefaults(
        agent: "plan",
        model: AgentModel(providerID: "provider-a", modelID: "model-c", variant: "xhigh"),
      ),
    );
    expect(
      await repository.read(pluginId: "plugin-b"),
      const SessionPromptDefaults(
        agent: "review",
        model: AgentModel(providerID: "provider-b", modelID: "model-b", variant: "low"),
      ),
    );
  });

  test("writing no selection clears a stale plugin default", () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = NewSessionDefaultsRepository(
      dao: NewSessionDefaultsDao(database: database),
    );

    await repository.write(
      pluginId: "plugin-a",
      defaults: const SessionPromptDefaults(
        agent: "build",
        model: AgentModel(providerID: "provider-a", modelID: "model-a", variant: "high"),
      ),
    );
    await repository.write(
      pluginId: "plugin-a",
      defaults: const SessionPromptDefaults(agent: null, model: null),
    );

    expect(await repository.read(pluginId: "plugin-a"), isNull);
  });
}

import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/new_session_defaults_dao.dart";
import "../api/database/database.dart";

class NewSessionDefaultsRepository({required final NewSessionDefaultsDao _dao}) {
  Future<SessionPromptDefaults?> read({required String pluginId}) async {
    final row = await _dao.getRow(pluginId: pluginId);
    if (row == null || (row.agent == null && row.agentModel == null)) return null;
    return SessionPromptDefaults(agent: row.agent, model: row.agentModel);
  }

  Future<void> write({required String pluginId, required SessionPromptDefaults defaults}) {
    return _dao.writeRow(
      row: NewSessionDefaultsTableData(
        pluginId: pluginId,
        agent: defaults.agent,
        agentModel: defaults.model,
      ),
    );
  }
}

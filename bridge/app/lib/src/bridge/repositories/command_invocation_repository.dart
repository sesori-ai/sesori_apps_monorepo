import "../../api/database/daos/command_invocation_dao.dart";
import "../../api/database/database.dart";
import "models/accepted_command_invocation.dart";

class CommandInvocationRepository {
  final CommandInvocationDao _dao;

  CommandInvocationRepository({required CommandInvocationDao dao}) : _dao = dao;

  Future<void> save({required AcceptedCommandInvocation invocation}) {
    return _dao.insertInvocation(
      invocation: AcceptedCommandInvocationDto(
        invocationId: invocation.invocationId,
        sessionId: invocation.sessionId,
        pluginId: invocation.pluginId,
        name: invocation.name,
        arguments: invocation.arguments,
        acceptedAt: invocation.acceptedAt,
        backendMessageId: invocation.backendMessageId,
      ),
    );
  }

  Future<void> updateBackendMessageId({required String invocationId, required String backendMessageId}) {
    return _dao.updateBackendMessageId(
      invocationId: invocationId,
      backendMessageId: backendMessageId,
    );
  }

  Future<List<AcceptedCommandInvocation>> getForSession({
    required String pluginId,
    required String sessionId,
  }) async {
    final rows = await _dao.getInvocationsForSession(pluginId: pluginId, sessionId: sessionId);
    return rows.map(_map).toList(growable: false);
  }

  Future<List<AcceptedCommandInvocation>> getForPlugin({required String pluginId}) async {
    final rows = await _dao.getInvocationsForPlugin(pluginId: pluginId);
    return rows.map(_map).toList(growable: false);
  }

  AcceptedCommandInvocation _map(AcceptedCommandInvocationDto row) {
    return AcceptedCommandInvocation(
      invocationId: row.invocationId,
      sessionId: row.sessionId,
      pluginId: row.pluginId,
      name: row.name,
      arguments: row.arguments,
      acceptedAt: row.acceptedAt,
      backendMessageId: row.backendMessageId,
    );
  }
}

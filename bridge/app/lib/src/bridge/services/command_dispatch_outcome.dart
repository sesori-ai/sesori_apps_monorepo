import "../repositories/models/accepted_command_invocation.dart";

sealed class CommandDispatchOutcome {
  final String pluginId;
  final String sessionId;
  final String invocationId;

  const CommandDispatchOutcome({
    required this.pluginId,
    required this.sessionId,
    required this.invocationId,
  });
}

class AcceptedCommandDispatchOutcome extends CommandDispatchOutcome {
  final AcceptedCommandInvocation invocation;

  AcceptedCommandDispatchOutcome({required this.invocation})
    : super(
        pluginId: invocation.pluginId,
        sessionId: invocation.sessionId,
        invocationId: invocation.invocationId,
      );
}

class RejectedCommandDispatchOutcome extends CommandDispatchOutcome {
  final Object error;
  final StackTrace stackTrace;

  const RejectedCommandDispatchOutcome({
    required super.pluginId,
    required super.sessionId,
    required super.invocationId,
    required this.error,
    required this.stackTrace,
  });

  Never rethrowOriginal() => Error.throwWithStackTrace(error, stackTrace);
}

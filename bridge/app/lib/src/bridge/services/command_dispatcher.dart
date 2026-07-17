import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show PromptModel, SessionVariant;

import "../foundation/uuid_v4_builder.dart";
import "../repositories/command_invocation_repository.dart";
import "../repositories/models/accepted_command_invocation.dart";
import "../repositories/models/command_dispatch_receipt.dart";
import "../repositories/session_repository.dart";
import "command_dispatch_outcome.dart";

class CommandDispatcher {
  final SessionRepository _sessionRepository;
  final CommandInvocationRepository _invocationRepository;
  final UuidV4Builder _uuidBuilder;
  final Clock _clock;
  final StreamController<CommandDispatchOutcome> _outcomesController =
      StreamController<CommandDispatchOutcome>.broadcast(sync: true);

  CommandDispatcher({
    required SessionRepository sessionRepository,
    required CommandInvocationRepository invocationRepository,
    required UuidV4Builder uuidBuilder,
    required Clock clock,
  }) : _sessionRepository = sessionRepository,
       _invocationRepository = invocationRepository,
       _uuidBuilder = uuidBuilder,
       _clock = clock;

  Stream<CommandDispatchOutcome> get outcomes => _outcomesController.stream;

  Future<AcceptedCommandDispatchOutcome> dispatch({
    required String sessionId,
    required String name,
    required String? arguments,
    required String? backendArguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    final invocationId = _uuidBuilder.generate();
    late final CommandDispatchReceipt receipt;
    try {
      receipt = await _sessionRepository.dispatchCommand(
        sessionId: sessionId,
        invocationId: invocationId,
        name: name,
        arguments: backendArguments,
        variant: variant,
        agent: agent,
        model: model,
      );
    } catch (error, stackTrace) {
      final outcome = RejectedCommandDispatchOutcome(
        pluginId: _sessionRepository.pluginId,
        sessionId: sessionId,
        invocationId: invocationId,
        error: error,
        stackTrace: stackTrace,
      );
      _outcomesController.add(outcome);
      Error.throwWithStackTrace(error, stackTrace);
    }
    final invocation = AcceptedCommandInvocation(
      invocationId: invocationId,
      sessionId: receipt.sessionId,
      pluginId: receipt.pluginId,
      name: name,
      arguments: arguments,
      acceptedAt: _clock.now().millisecondsSinceEpoch,
      backendMessageId: receipt.backendMessageId,
    );
    try {
      await _invocationRepository.save(invocation: invocation);
    } catch (error, stackTrace) {
      Log.w("Failed to persist accepted command ${invocation.invocationId}", error, stackTrace);
    }
    final outcome = AcceptedCommandDispatchOutcome(invocation: invocation);
    _outcomesController.add(outcome);
    return outcome;
  }

  Future<void> dispose() => _outcomesController.close();
}

import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/pi_catalog_dto.dart";
import "../api/models/pi_extension_ui_request.dart";
import "../api/models/pi_rpc_frame.dart";
import "../api/pi_launch_spec.dart";
import "../api/pi_process_factory.dart";
import "../api/pi_rpc_client.dart";
import "../models/pi_rpc_command.dart";
import "../models/pi_thinking_level.dart";

typedef PiCatalogProbeSnapshot = ({
  List<PluginAgent> agents,
  PluginProvidersResult providers,
  List<PluginCommand> commands,
  bool complete,
});

final class const PiCatalogProbeException({required final Object cause, required final List<String> stderrDiagnostics})
    implements Exception {
  @override
  String toString() =>
      "PiCatalogProbeException(cause: $cause${stderrDiagnostics.isEmpty ? "" : ", stderr: ${stderrDiagnostics.join(" | ")}"})";
}

class PiBackendCatalogRepository({
  required final String _binaryPath,
  required final Map<String, String> _environment,
  required final PiProcessFactory _processFactory,
}) {
  Future<PiCatalogProbeSnapshot> probe({
    required String projectId,
    required Duration totalTimeout,
    required int maxModels,
  }) async {
    final stopwatch = Stopwatch()..start();
    final normalizedProject = normalizeProjectDirectory(directory: projectId);
    final client = PiRpcClient(
      launchSpec: PiLaunchSpec(
        binaryPath: _binaryPath,
        workingDirectory: normalizedProject,
        launch: const PiNoSession(),
        environment: _environment,
      ),
      processFactory: _processFactory,
    );
    late final StreamSubscription<PiRpcFrame> frames;
    frames = client.frames.listen((frame) {
      if (frame case PiExtensionUiFrame(:final request) when request is PiExtensionDialogRequest) {
        client.sendExtensionUiResponse(id: request.id, reply: const PiExtensionUiCancelledReply());
      }
    });

    try {
      await client.start().timeout(_remaining(stopwatch: stopwatch, totalTimeout: totalTimeout));
      final state = PiStateCatalogDto.fromJson(
        (await _send(
          client: client,
          command: PiRpcCommand.getState,
          arguments: const {},
          timeout: _remaining(stopwatch: stopwatch, totalTimeout: totalTimeout),
        )).data,
      );
      final initial = state.model;
      if (!_validModel(initial)) throw StateError("Pi catalog probe has no selected model");
      final initialModel = initial!;

      final available = PiAvailableModelsDto.fromJson(
        (await _send(
          client: client,
          command: PiRpcCommand.getAvailableModels,
          arguments: const {},
          timeout: _remaining(stopwatch: stopwatch, totalTimeout: totalTimeout),
        )).data,
      );
      final deduped = _dedupeModels(available.models);
      if (deduped.isEmpty) throw StateError("Pi catalog probe returned no models");
      final initialIndex = deduped.indexWhere((model) => _sameModel(model, initialModel));
      if (initialIndex < 0) throw StateError("Pi selected model is absent from the catalog");
      if (initialIndex > 0) deduped.insert(0, deduped.removeAt(initialIndex));
      final bounded = deduped.take(maxModels).toList();

      var partial = deduped.length > bounded.length;
      final thinkingByModel = <String, List<String>>{};
      for (final model in bounded.where((model) => model.reasoning)) {
        try {
          await _send(
            client: client,
            command: PiRpcCommand.setModel,
            arguments: {"provider": model.provider, "modelId": model.id},
            timeout: _remaining(stopwatch: stopwatch, totalTimeout: totalTimeout),
          );
          final thinking = PiThinkingLevelsDto.fromJson(
            (await _send(
              client: client,
              command: PiRpcCommand.getAvailableThinkingLevels,
              arguments: const {},
              timeout: _remaining(stopwatch: stopwatch, totalTimeout: totalTimeout),
            )).data,
          );
          thinkingByModel[_modelKey(model)] = _thinkingLevels(thinking.levels);
        } on PiRpcProcessExitException {
          rethrow;
        } on Object catch (error, stack) {
          partial = true;
          Log.w("[pi] model thinking discovery failed; continuing", error, stack);
          if (error is TimeoutException) break;
        }
      }

      List<PluginCommand> commands;
      try {
        final commandDtos = PiCommandsDto.fromJson(
          (await _send(
            client: client,
            command: PiRpcCommand.getCommands,
            arguments: const {},
            timeout: _remaining(stopwatch: stopwatch, totalTimeout: totalTimeout),
          )).data,
        );
        commands = [for (final command in commandDtos.commands) ?_command(command)];
      } on TimeoutException {
        rethrow;
      } on PiRpcProcessExitException {
        rethrow;
      } on Object catch (error, stack) {
        partial = true;
        commands = const [];
        Log.w("[pi] command discovery failed; continuing", error, stack);
      }

      return (
        agents: [
          const PluginAgent(
            name: "pi",
            description: null,
            model: null,
            mode: PluginAgentMode.primary,
            hidden: false,
          ),
        ],
        providers: PluginProvidersResult(
          providers: _providers(
            models: bounded,
            initial: initialModel,
            thinkingByModel: thinkingByModel,
          ),
        ),
        commands: commands,
        complete: !partial,
      );
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(
        PiCatalogProbeException(
          cause: error,
          stderrDiagnostics: client.stderrDiagnostics,
        ),
        stack,
      );
    } finally {
      try {
        await client.dispose(gracefulTimeout: const Duration(seconds: 1));
      } on Object catch (error, stack) {
        Log.w("[pi] catalog probe process teardown failed", error, stack);
      }
      try {
        await frames.cancel();
      } on Object catch (error, stack) {
        Log.w("[pi] catalog probe frame listener teardown failed", error, stack);
      }
    }
  }

  Future<PiSuccessResponseFrame> _send({
    required PiRpcClient client,
    required PiRpcCommand command,
    required Map<String, Object?> arguments,
    required Duration timeout,
  }) => client.send(command: command, arguments: arguments, timeout: timeout);

  Duration _remaining({required Stopwatch stopwatch, required Duration totalTimeout}) {
    final remaining = totalTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException("Pi catalog probe exceeded $totalTimeout");
    return remaining;
  }

  List<PiCatalogModelDto> _dedupeModels(List<PiCatalogModelDto> models) {
    final seen = <String>{};
    return [
      for (final model in models)
        if (_validModel(model) && seen.add(_modelKey(model))) model,
    ];
  }

  List<String> _thinkingLevels(List<String> values) {
    final seen = <PiThinkingLevel>{};
    return [
      for (final value in values)
        if (PiThinkingLevel.tryParse(value: value) case final level? when seen.add(level)) level.wireValue,
    ];
  }

  List<PluginProvider> _providers({
    required List<PiCatalogModelDto> models,
    required PiCatalogModelDto initial,
    required Map<String, List<String>> thinkingByModel,
  }) {
    final grouped = <String, List<PiCatalogModelDto>>{};
    for (final model in models) {
      (grouped[model.provider!] ??= []).add(model);
    }
    final entries = grouped.entries.toList();
    final initialIndex = entries.indexWhere((entry) => entry.key == initial.provider);
    if (initialIndex > 0) entries.insert(0, entries.removeAt(initialIndex));
    return [
      for (final entry in entries)
        _provider(
          id: entry.key,
          models: [
            for (final model in entry.value)
              PluginModel(
                id: model.id!,
                name: _displayName(model),
                variants: thinkingByModel[_modelKey(model)] ?? const [],
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ],
          defaultModelId: entry.key == initial.provider ? initial.id : null,
        ),
    ];
  }

  PluginProvider _provider({
    required String id,
    required List<PluginModel> models,
    required String? defaultModelId,
  }) {
    final fields = (
      id: id,
      name: id,
      authType: PluginProviderAuthType.unknown,
      models: models,
      defaultModelID: defaultModelId,
    );
    return switch (id.toLowerCase()) {
      "anthropic" => PluginProvider.anthropic(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "openai" => PluginProvider.openAI(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "google" => PluginProvider.google(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "mistral" => PluginProvider.mistral(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "groq" => PluginProvider.groq(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "xai" => PluginProvider.xAI(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "deepseek" => PluginProvider.deepseek(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "amazon-bedrock" || "bedrock" => PluginProvider.amazonBedrock(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      "azure" || "azure-openai-responses" => PluginProvider.azure(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
      _ => PluginProvider.custom(
        id: fields.id,
        name: fields.name,
        authType: fields.authType,
        models: fields.models,
        defaultModelID: fields.defaultModelID,
      ),
    };
  }

  PluginCommand? _command(PiCatalogCommandDto dto) {
    final name = dto.name?.trim();
    if (name == null || name.isEmpty) return null;
    final description = dto.description?.trim();
    return PluginCommand(
      name: name,
      description: description == null || description.isEmpty ? null : description,
      provider: null,
      source: switch (dto.source) {
        PiCatalogCommandSource.extension ||
        PiCatalogCommandSource.promptTemplate ||
        PiCatalogCommandSource.prompt => PluginCommandSource.command,
        PiCatalogCommandSource.skill => PluginCommandSource.skill,
        PiCatalogCommandSource.unknown => PluginCommandSource.unknown,
      },
    );
  }

  bool _validModel(PiCatalogModelDto? model) =>
      (model?.provider?.isNotEmpty ?? false) && (model?.id?.isNotEmpty ?? false);

  bool _sameModel(PiCatalogModelDto left, PiCatalogModelDto right) => _modelKey(left) == _modelKey(right);

  String _modelKey(PiCatalogModelDto model) => "${model.provider}\u0000${model.id}";

  String _displayName(PiCatalogModelDto model) {
    final name = model.name?.trim();
    return name == null || name.isEmpty ? model.id! : name;
  }
}

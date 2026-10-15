import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginExternalActionMapping on PluginPendingExternalAction {
  PendingExternalAction toShared({required String sessionId, required String? displaySessionId}) =>
      PendingExternalAction(
        id: id,
        sessionID: sessionId,
        displaySessionId: displaySessionId,
        title: title,
        message: message,
        authorizationUrl: authorizationUrl,
        purpose: switch (purpose) {
          PluginExternalActionPurpose.authorization => ExternalActionPurpose.authorization,
          PluginExternalActionPurpose.connectorConsent => ExternalActionPurpose.connectorConsent,
        },
        choices: choices.map((choice) => choice.toShared()).toList(growable: false),
      );
}

extension PluginExternalActionChoiceMapping on PluginExternalActionChoice {
  ExternalActionChoice toShared() => switch (this) {
    PluginExternalActionChoice.accept => ExternalActionChoice.accept,
    PluginExternalActionChoice.decline => ExternalActionChoice.decline,
    PluginExternalActionChoice.cancel => ExternalActionChoice.cancel,
  };
}

extension ExternalActionChoiceMapping on ExternalActionChoice {
  PluginExternalActionChoice? toPlugin() => switch (this) {
    ExternalActionChoice.accept => PluginExternalActionChoice.accept,
    ExternalActionChoice.decline => PluginExternalActionChoice.decline,
    ExternalActionChoice.cancel => PluginExternalActionChoice.cancel,
    ExternalActionChoice.unknown => null,
  };
}

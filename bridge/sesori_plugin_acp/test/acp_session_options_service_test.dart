import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("configuration tracker owns process defaults and per-session overrides", () {
    final tracker = AcpSessionConfigurationTracker()
      ..setProcessDefaults(modelId: "default-model", providerId: "provider")
      ..setSessionOverride(
        sessionId: "session",
        modelId: "session-model",
        providerId: "session-provider",
      );
    final mapper = AcpEventMapper(
      launchDirectory: "/repo",
      pluginId: "plugin",
      configurationTracker: tracker,
      childSessions: AcpChildSessionTracker(),
    );

    final defaultEvents = mapper.map(_messageUpdate(sessionId: "other"));
    final overrideEvents = mapper.map(_messageUpdate(sessionId: "session"));
    final defaultMessage = defaultEvents.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant;
    final overrideMessage = overrideEvents.whereType<BridgeSseMessageUpdated>().single.info as PluginMessageAssistant;

    expect((defaultMessage.modelID, defaultMessage.providerID), ("default-model", "provider"));
    expect((overrideMessage.modelID, overrideMessage.providerID), ("session-model", "session-provider"));

    tracker.forgetSession(sessionId: "session");
    expect(mapper.modelForSession(sessionId: "session"), "default-model");
    expect(mapper.providerForSession(sessionId: "session"), "provider");
  });

  test("configuration tracker keeps explicit null variant distinct from no session override", () {
    final tracker = AcpSessionConfigurationTracker()
      ..setProcessSelection(modelId: "default-model", providerId: "provider", variantId: "high")
      ..setSessionSelection(
        sessionId: "session",
        modelId: "plain-model",
        providerId: "provider",
        variantId: null,
      );

    expect(tracker.snapshotForSession(sessionId: "session").variantId, isNull);
    tracker.forgetSession(sessionId: "session");
    expect(tracker.snapshotForSession(sessionId: "session").variantId, "high");
    tracker.clear();
    expect(tracker.processDefaults.variantId, isNull);
  });

  test("ACP aggregate becomes complete after an authoritative command snapshot", () {
    final configurationTracker = AcpSessionConfigurationTracker()
      ..setProcessDefaults(modelId: "model", providerId: "provider");
    final commandTracker = AcpCommandTracker();
    final service = AcpSessionOptionsService(
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      pluginId: "acp",
      agentDisplayName: "ACP",
    );

    expect(service.getSessionOptions().completeness, PluginSessionOptionsCompleteness.partial);

    commandTracker.consume(
      const AcpNotification(
        method: "session/update",
        params: {
          "sessionId": "session",
          "update": {
            "sessionUpdate": "available_commands_update",
            "availableCommands": [
              {"name": "review"},
            ],
          },
        },
      ),
    );
    final options = service.getSessionOptions();

    expect(options.completeness, PluginSessionOptionsCompleteness.complete);
    expect(options.agents.single.model?.modelID, "model");
    expect(options.providers.providers.single.defaultModelID, "model");
    expect(options.commands.single.name, "review");
  });
}

AcpNotification _messageUpdate({required String sessionId}) => AcpNotification(
  method: "session/update",
  params: {
    "sessionId": sessionId,
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "content": {"type": "text", "text": "hello"},
    },
  },
);

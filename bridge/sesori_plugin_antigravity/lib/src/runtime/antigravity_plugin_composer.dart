import "package:acp_plugin/acp_plugin.dart";

import "../antigravity_event_mapper.dart";
import "../antigravity_plugin_impl.dart";
import "../builders/antigravity_launch_spec_builder.dart";
import "../foundation/antigravity_identity.dart";
import "../models/antigravity_profile.dart";
import "../models/antigravity_runtime_pair.dart";
import "../repositories/antigravity_session_metadata_repository.dart";
import "../repositories/mappers/antigravity_authorization_mapper.dart";
import "../repositories/mappers/antigravity_protocol_mapper.dart";
import "../repositories/mappers/antigravity_stderr_mapper.dart";
import "../services/antigravity_session_metadata_service.dart";
import "../services/antigravity_session_options_service.dart";
import "../storage/antigravity_session_metadata_storage.dart";
import "../trackers/antigravity_catalog_tracker.dart";
import "antigravity_interaction_composer.dart";
import "antigravity_output_composer.dart";

/// Consumes a validated pair and prepared isolated profile. The caller owns
/// preparation/probing and provides its host-backed process factory.
class const AntigravityPluginComposer() {
  AntigravityPlugin compose({
    required AntigravityRuntimePair pair,
    required AntigravityPreparedProfile profile,
    required String launchDirectory,
    required AcpProcessFactory processFactory,
  }) {
    const protocol = AntigravityProtocolMapper();
    final configuration = AcpSessionConfigurationTracker();
    final commands = AcpCommandTracker();
    final children = AcpChildSessionTracker();
    final catalog = AntigravityCatalogTracker();
    return AntigravityPlugin(
      launchSpec: const AntigravityLaunchSpecBuilder().build(
        pair: pair,
        cwd: launchDirectory,
        environment: profile.environment,
      ),
      launchDirectory: launchDirectory,
      processFactory: processFactory,
      eventMapper: AntigravityEventMapper(
        launchDirectory: launchDirectory,
        pluginId: AntigravityIdentity.pluginId,
        configurationTracker: configuration,
        childSessions: children,
        protocolMapper: protocol,
      ),
      childSessionTracker: children,
      commandTracker: commands,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configuration,
        commandTracker: commands,
        pluginId: AntigravityIdentity.pluginId,
        agentDisplayName: AntigravityIdentity.displayName,
      ),
      options: AntigravitySessionOptionsService(protocolMapper: protocol, catalogTracker: catalog),
      catalog: catalog,
      metadata: AntigravitySessionMetadataService(
        repository: AntigravitySessionMetadataRepository(storage: const AntigravitySessionMetadataStorage()),
      ),
      geminiHome: profile.geminiHome,
      interactions: const AntigravityInteractionComposer(protocolMapper: protocol),
      output: const AntigravityOutputComposer(
        authorizationMapper: AntigravityAuthorizationMapper(),
        stderrMapper: AntigravityStderrMapper(),
      ),
    );
  }
}

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../antigravity_approval_registry.dart";
import "../repositories/antigravity_interaction_repository.dart";
import "../repositories/mappers/antigravity_protocol_mapper.dart";
import "../services/antigravity_interaction_service.dart";

class const AntigravityInteractionComposer({required final AntigravityProtocolMapper protocolMapper}) {
  AntigravityApprovalRegistry compose({required AcpStdioClient client, required void Function(BridgeSseEvent) emit}) =>
      AntigravityApprovalRegistry(
        interactionService: AntigravityInteractionService(
          protocolMapper: protocolMapper,
          repository: AntigravityInteractionRepository(client: client),
        ),
        emit: emit,
        idGenerator: null,
      );
}

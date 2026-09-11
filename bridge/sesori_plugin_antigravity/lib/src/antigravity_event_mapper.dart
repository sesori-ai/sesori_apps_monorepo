import "package:acp_plugin/acp_plugin.dart";

import "repositories/mappers/antigravity_protocol_mapper.dart";

class AntigravityEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final AntigravityProtocolMapper _protocolMapper,
}) extends AcpEventMapper {
  @override
  String? shellCommandForToolUpdate({required Map<String, dynamic> update}) =>
      _protocolMapper.shellCommandForToolUpdate(update: update);

  @override
  Map<String, dynamic> normalizeSessionUpdate({required Map<String, dynamic> params}) =>
      _protocolMapper.normalizeSessionUpdate(params: params);
}

import "package:acp_plugin/acp_plugin.dart";
import "package:json_annotation/json_annotation.dart";

import "../../models/antigravity_interaction.dart";
import "../../models/antigravity_model_catalog.dart";
import "models/antigravity_model_config_dto.dart";
import "models/antigravity_permission_dto.dart";

/// Layer-2 boundary for Antigravity's ACP catalogs and permission requests.
class const AntigravityProtocolMapper() {
  static const modelConfigId = "model";

  AntigravityPermissionRequestDto? mapPermissionRequest({required AcpServerRequest request}) {
    if (request.method != AcpMethods.sessionRequestPermission) return null;
    try {
      return AntigravityPermissionRequestDto.fromJson(request.params);
    } on CheckedFromJsonException catch (error, stackTrace) {
      // Generated field/class names diagnose shape changes without rendering the
      // offending value or the decoder's potentially payload-bearing message.
      Error.throwWithStackTrace(
        AntigravityInteractionException(
          message: "Invalid ${error.className}.${error.key}: ${error.innerError.runtimeType.toString()}",
          cause: error,
        ),
        error.innerStack ?? stackTrace,
      );
    }
  }

  AntigravityModelCatalog? mapModelCatalog({required AcpNewSessionResult result}) {
    final selectors = result.configOptions.where((option) => option["id"] == modelConfigId).toList();
    if (selectors.isEmpty) return null;
    if (selectors.length != 1) throw const FormatException("Duplicate Antigravity model selectors");
    final config = AntigravityModelConfigDto.fromJson(selectors.single);
    if (config.type != AntigravityConfigType.select) {
      throw const FormatException("Antigravity model selector is not a supported select option");
    }
    return AntigravityModelCatalog(
      configId: config.id,
      currentModelId: config.currentValue,
      models: [for (final option in config.options) AntigravityModelOption(id: option.value, name: option.name)],
    );
  }
}

import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_prompt_part.freezed.dart";

part "plugin_prompt_part.g.dart";

@freezed
sealed class PluginPromptPart with _$PluginPromptPart {
  const factory PluginPromptPart.text({required String text}) = PluginPromptPartText;
  const factory PluginPromptPart.filePath({required String mime, required String path, required String? filename}) =
      PluginPromptPartFilePath;
  const factory PluginPromptPart.fileUrl({required String mime, required String url, required String? filename}) =
      PluginPromptPartFileUrl;
  const factory PluginPromptPart.fileData({required String mime, required String base64, required String? filename}) =
      PluginPromptPartFileData;
}

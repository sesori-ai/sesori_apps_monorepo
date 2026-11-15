import "package:freezed_annotation/freezed_annotation.dart";

part "deliverable_prompt_part.freezed.dart";

/// A prompt part in the form a plugin receives it. A file on this computer
/// reaches the plugin only as a text note naming its path, so no variant
/// carries a local path.
@Freezed(copyWith: false)
sealed class DeliverablePromptPart with _$DeliverablePromptPart {
  const factory text({required String text}) = DeliverablePromptPartText;
  const factory fileUrl({required String mime, required String url, required String? filename}) =
      DeliverablePromptPartFileUrl;
  const factory fileData({required String mime, required String base64, required String? filename}) =
      DeliverablePromptPartFileData;

  /// What the user sees of a prompt sent as [parts]: its non-blank texts, a
  /// blank line apart, so the live message matches the reloaded one.
  static String? userVisibleText({required List<DeliverablePromptPart> parts}) {
    final texts = [
      for (final part in parts)
        if (part case DeliverablePromptPartText(:final text) when text.trim().isNotEmpty) text,
    ];
    return texts.isEmpty ? null : texts.join("\n\n");
  }
}

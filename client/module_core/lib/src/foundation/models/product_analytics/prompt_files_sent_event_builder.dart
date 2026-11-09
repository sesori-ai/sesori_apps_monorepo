import "../composer/composer_attachment.dart";
import "product_analytics_event.dart";

/// The `prompt_files_sent` event for an accepted prompt carrying
/// [attachments], or `null` when none of them is a file the bridge saves.
/// Inline images are not counted.
PromptFilesSentEvent? promptFilesSentEvent({required List<ComposerAttachment> attachments}) {
  final files = attachments.whereType<ComposerFileAttachment>().toList();
  if (files.isEmpty) return null;
  final sources = {for (final file in files) file.source};
  return PromptFilesSentEvent(
    fileCount: switch (files.length) {
      1 => AnalyticsFileCountBucket.one,
      <= 4 => AnalyticsFileCountBucket.twoToFour,
      _ => AnalyticsFileCountBucket.fivePlus,
    },
    source: sources.length > 1
        ? AnalyticsFileSource.mixed
        : switch (sources.single) {
            ComposerAttachmentSource.picker => AnalyticsFileSource.picker,
            ComposerAttachmentSource.drop => AnalyticsFileSource.drop,
            ComposerAttachmentSource.paste => AnalyticsFileSource.paste,
          },
  );
}

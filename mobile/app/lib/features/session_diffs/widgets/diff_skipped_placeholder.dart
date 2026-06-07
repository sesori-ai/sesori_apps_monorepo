import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../core/extensions/build_context_x.dart";

class DiffSkippedPlaceholder extends StatelessWidget {
  final FileDiffSkipReason reason;

  const DiffSkippedPlaceholder({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final message = switch (reason) {
      FileDiffSkipReason.binary => loc.diffBinaryFileChanged,
      FileDiffSkipReason.tooLarge => loc.diffFileTooLarge,
      FileDiffSkipReason.readError => loc.diffCouldNotReadFile,
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: context.zyra.textTheme.textXs.regular.copyWith(
          color: context.zyra.colors.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "file_part_widget.dart";

class const UserMessageCard({super.key, required final MessageWithParts message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final text = message.parts
        .where((part) => part.type == MessagePartType.text)
        .map((part) => part.text ?? "")
        .join("\n");
    final attachments = message.parts
        .where((part) => part.type == MessagePartType.file)
        .map((part) => part.attachment)
        .whereType<MessageAttachment>()
        .toList();

    return Align(
      alignment: .centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: prego.colors.bgBrandPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: .end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachments.isNotEmpty) ...attachments.map((attachment) => FilePartWidget(attachment: attachment)),
            if (text.isNotEmpty)
              SelectionArea(
                child: Text(
                  text,
                  style: prego.textTheme.textSm.regular.copyWith(
                    color: prego.colors.textBrandPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

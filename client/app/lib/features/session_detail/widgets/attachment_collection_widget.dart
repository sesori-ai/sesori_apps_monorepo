import "dart:math" as math;

import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "file_part_widget.dart";

class const AttachmentCollectionWidget({
  super.key,
  required final String sessionId,
  required final List<MessageAttachment> attachments,
}) extends StatelessWidget {
  static const surfaceKey = ValueKey("attachmentCollection.surface");

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, PregoWidths.xxs);
        final rows = <Widget>[];
        var index = 0;
        if (attachments.length.isOdd) {
          rows.add(_tile(index: 0, attachment: attachments.first));
          index = 1;
        }
        while (index < attachments.length) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _tile(index: index, attachment: attachments[index]),
                ),
                const SizedBox(width: PregoSpacing.sm),
                Expanded(
                  child: _tile(index: index + 1, attachment: attachments[index + 1]),
                ),
              ],
            ),
          );
          index += 2;
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: surfaceKey,
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PregoSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: PregoSpacing.sm,
                children: rows,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tile({required int index, required MessageAttachment attachment}) => FilePartWidget(
    key: ValueKey((index, attachment)),
    sessionId: sessionId,
    attachment: attachment,
  );
}

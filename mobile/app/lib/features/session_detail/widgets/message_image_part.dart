import "dart:convert";

import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

/// Renders a `file` [MessagePart] inline. Image parts whose `url` is a
/// `data:` URI or an `http(s)` URL are shown as a bounded thumbnail; anything
/// that cannot be rendered as an image falls back to a filename chip.
class MessageImagePart extends StatelessWidget {
  final MessagePart part;

  const MessageImagePart({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    if (image == null) {
      return _FileChip(label: part.filename ?? part.mime ?? "file");
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      ),
    );
  }

  Widget? _buildImage() {
    final url = part.url;
    if (url == null || (part.mime?.startsWith("image/") != true)) return null;

    if (url.startsWith("data:")) {
      final commaIndex = url.indexOf(",");
      if (commaIndex == -1 || !url.substring(0, commaIndex).contains("base64")) return null;
      try {
        return Image.memory(base64Decode(url.substring(commaIndex + 1)), fit: BoxFit.cover);
      } on FormatException {
        return null;
      }
    }

    if (url.startsWith("http://") || url.startsWith("https://")) {
      return Image.network(url, fit: BoxFit.cover);
    }

    return null;
  }
}

class _FileChip extends StatelessWidget {
  final String label;

  const _FileChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: zyra.colors.bgQuaternary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 16, color: zyra.colors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: zyra.textTheme.textSm.regular.copyWith(color: zyra.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

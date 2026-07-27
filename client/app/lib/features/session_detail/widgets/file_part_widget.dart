import "dart:convert";

import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "package:url_launcher/url_launcher.dart";

class FilePartWidget extends StatelessWidget {
  final MessagePart part;

  const FilePartWidget({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final mime = part.mime ?? "";
    final url = part.url;
    final base64 = part.base64;
    final filename = part.filename ?? (url != null ? url.split("/").last : "file");
    final isImage = mime.startsWith("image/");

    if (isImage) {
      return _buildImage(context, prego, url, base64, filename);
    }
    return _buildFileLink(context, prego, filename, url, mime);
  }

  Widget _buildImage(BuildContext context, IPregoTheme prego, String? url, String? base64, String filename) {
    if (base64 != null) {
      final bytes = base64Decode(base64);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 48, color: prego.colors.textTertiary),
          ),
        ),
      );
    }
    if (url != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 48, color: prego.colors.textTertiary),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFileLink(BuildContext context, IPregoTheme prego, String filename, String? url, String mime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: url != null ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: prego.colors.bgSurfaceSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file, size: 20, color: prego.colors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(filename, style: prego.textTheme.textSm.regular, overflow: TextOverflow.ellipsis),
              ),
              if (url != null)
                Icon(Icons.open_in_new, size: 16, color: prego.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

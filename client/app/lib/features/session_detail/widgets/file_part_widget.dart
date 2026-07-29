import "dart:convert";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/external_link.dart";
import "../../../l10n/app_localizations.dart";

class FilePartWidget extends StatelessWidget {
  final MessagePart part;

  const FilePartWidget({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final mime = part.mime ?? "";
    final url = part.url;
    final base64 = part.base64;
    final filename = part.filename ?? _deriveFilename(url, part.path, context);
    final isImage = mime.startsWith("image/");

    if (isImage) {
      return _buildImage(
        context: context,
        prego: prego,
        url: url,
        base64: base64,
        filename: filename,
      );
    }
    return _buildFileLink(
      context: context,
      prego: prego,
      filename: filename,
      url: url,
      mime: mime,
    );
  }

  static String _deriveFilename(String? url, String? path, BuildContext context) {
    if (url != null) {
      final segments = Uri.tryParse(url)?.pathSegments;
      if (segments != null && segments.isNotEmpty && segments.last.isNotEmpty) {
        return segments.last;
      }
    }
    if (path != null && path.isNotEmpty) {
      final segments = path.split(RegExp(r"[/\\]"));
      if (segments.isNotEmpty && segments.last.isNotEmpty) {
        return segments.last;
      }
    }
    return context.loc.sessionDetailFileUnknown;
  }

  Widget _buildImage({
    required BuildContext context,
    required IPregoTheme prego,
    String? url,
    String? base64,
    required String filename,
  }) {
    if (base64 != null) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(base64);
      } on FormatException {
        logw("FilePartWidget: malformed base64 for $filename");
      }
      if (bytes != null) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: prego.spacing.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(prego.radius.xl),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 48, color: prego.colors.textTertiary),
            ),
          ),
        );
      }
    }
    if (url != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: prego.spacing.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(prego.radius.xl),
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

  Widget _buildFileLink({
    required BuildContext context,
    required IPregoTheme prego,
    required String filename,
    String? url,
    required String mime,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: prego.spacing.xs),
      child: GestureDetector(
        onTap: url != null ? () => unawaited(openExternalLink(url: Uri.parse(url))) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: prego.spacing.lg, vertical: prego.spacing.md),
          decoration: BoxDecoration(
            color: prego.colors.bgSurfaceSecondary,
            borderRadius: BorderRadius.circular(prego.radius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file, size: 20, color: prego.colors.textSecondary),
              SizedBox(width: prego.spacing.md),
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

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../models/pi_notification_type.dart";
import "pi_frame_fields.dart";

/// One `extension_ui_request` frame from Pi v0.84.1.
///
/// Pi mixes two unrelated things under this one wire type: dialogs that block
/// an extension until Sesori answers on stdin, and fire-and-forget terminal
/// decorations that expect no answer at all. The variants below keep that split
/// explicit so a consumer cannot accidentally leave a dialog unanswered or
/// invent a reply to a notification.
sealed class const PiExtensionUiRequest({required this.id, required this.raw}) {
  /// Pi's own request ID, echoed in an `extension_ui_response`.
  final String id;

  final Map<String, Object?> raw;

  /// Routes one request. Returns null when `id` is missing or not a string:
  /// without it no reply can ever be correlated, so it is not a dialog.
  static PiExtensionUiRequest? parse({required Map<String, Object?> json}) {
    final id = stringOrNull(json["id"]);
    if (id == null) return null;
    final title = stringOrNull(json["title"]);
    final timeout = intOrNull(json["timeout"]);

    return switch (stringOrNull(json["method"])) {
      "select" => PiSelectDialogRequest(
        id: id,
        title: title,
        options: stringListOrNull(json["options"]) ?? const [],
        timeoutMs: timeout,
        raw: json,
      ),
      "confirm" => PiConfirmDialogRequest(
        id: id,
        title: title,
        message: stringOrNull(json["message"]),
        timeoutMs: timeout,
        raw: json,
      ),
      "input" => PiInputDialogRequest(
        id: id,
        title: title,
        placeholder: stringOrNull(json["placeholder"]),
        timeoutMs: timeout,
        raw: json,
      ),
      // Pi has no upstream editor timeout; the plugin owns that expiry.
      "editor" => PiEditorDialogRequest(id: id, title: title, prefill: stringOrNull(json["prefill"]), raw: json),
      "notify" => PiNotifyRequest(
        id: id,
        message: stringOrNull(json["message"]),
        notifyType: _notificationType(stringOrNull(json["notifyType"])),
        raw: json,
      ),
      "setStatus" => PiSetStatusRequest(
        id: id,
        statusKey: stringOrNull(json["statusKey"]),
        statusText: stringOrNull(json["statusText"]),
        raw: json,
      ),
      "setWidget" => PiSetWidgetRequest(
        id: id,
        widgetKey: stringOrNull(json["widgetKey"]),
        widgetLines: stringListOrNull(json["widgetLines"]),
        widgetPlacement: stringOrNull(json["widgetPlacement"]),
        raw: json,
      ),
      "setTitle" => PiSetTitleRequest(id: id, title: title, raw: json),
      "set_editor_text" => PiSetEditorTextRequest(id: id, text: stringOrNull(json["text"]), raw: json),
      _ => _unknownExtensionUiRequest(id: id, json: json),
    };
  }
}

PiNotificationType? _notificationType(String? value) {
  final type = PiNotificationType.tryParse(value: value);
  if (value != null && type == null) Log.w("[pi] received an unknown notification type");
  return type;
}

PiExtensionUiRequest _unknownExtensionUiRequest({required String id, required Map<String, Object?> json}) {
  Log.w("[pi] received an unknown extension UI method");
  return PiUnknownExtensionUiRequest(id: id, method: stringOrNull(json["method"]), raw: json);
}

/// A request that blocks an extension until an `extension_ui_response` arrives.
sealed class const PiExtensionDialogRequest({required this.title, required super.id, required super.raw}) extends PiExtensionUiRequest {
  final String? title;
}

final class const PiSelectDialogRequest({
    required super.id,
    required super.title,
    required this.options,
    required this.timeoutMs,
    required super.raw,
  }) extends PiExtensionDialogRequest {
  final List<String> options;

  /// Pi resolves this dialog itself when the timeout elapses.
  final int? timeoutMs;
}

final class const PiConfirmDialogRequest({
    required super.id,
    required super.title,
    required this.message,
    required this.timeoutMs,
    required super.raw,
  }) extends PiExtensionDialogRequest {
  final String? message;
  final int? timeoutMs;
}

final class const PiInputDialogRequest({
    required super.id,
    required super.title,
    required this.placeholder,
    required this.timeoutMs,
    required super.raw,
  }) extends PiExtensionDialogRequest {
  final String? placeholder;
  final int? timeoutMs;
}

/// An editor dialog. Pi never expires this one, so the plugin owns its expiry.
final class const PiEditorDialogRequest({
    required super.id,
    required super.title,
    required this.prefill,
    required super.raw,
  }) extends PiExtensionDialogRequest {
  final String? prefill;
}

/// A decoration Pi emits without waiting for any reply.
sealed class const PiExtensionDecorationRequest({required super.id, required super.raw}) extends PiExtensionUiRequest;

final class const PiNotifyRequest({required super.id, required this.message, required this.notifyType, required super.raw}) extends PiExtensionDecorationRequest {
  final String? message;

  final PiNotificationType? notifyType;
}

final class const PiSetStatusRequest({required super.id, required this.statusKey, required this.statusText, required super.raw}) extends PiExtensionDecorationRequest {
  final String? statusKey;

  /// Null clears the status entry.
  final String? statusText;
}

final class const PiSetWidgetRequest({
    required super.id,
    required this.widgetKey,
    required this.widgetLines,
    required this.widgetPlacement,
    required super.raw,
  }) extends PiExtensionDecorationRequest {
  final String? widgetKey;

  /// Null clears the widget.
  final List<String>? widgetLines;

  final String? widgetPlacement;
}

final class const PiSetTitleRequest({required super.id, required this.title, required super.raw}) extends PiExtensionDecorationRequest {
  final String? title;
}

final class const PiSetEditorTextRequest({required super.id, required this.text, required super.raw}) extends PiExtensionDecorationRequest {
  final String? text;
}

/// An extension-UI method this build does not model. Treated as fire-and-forget
/// because answering an unknown method could resolve it with a wrong shape.
final class const PiUnknownExtensionUiRequest({required super.id, required this.method, required super.raw}) extends PiExtensionUiRequest {
  final String? method;
}

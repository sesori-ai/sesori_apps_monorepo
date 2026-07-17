import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

enum AcpMessageChunkRole { user, assistant, thought }

sealed class AcpNotificationRecord {
  const AcpNotificationRecord();

  String? get sessionId;
}

sealed class AcpSessionNotificationRecord extends AcpNotificationRecord {
  const AcpSessionNotificationRecord({required this.sessionId});

  @override
  final String sessionId;
}

class AcpMessageChunkRecord extends AcpSessionNotificationRecord {
  const AcpMessageChunkRecord({
    required super.sessionId,
    required this.role,
    required this.messageId,
    required this.text,
  });

  final AcpMessageChunkRole role;
  final String? messageId;
  final String? text;
}

class AcpToolUpdateRecord extends AcpSessionNotificationRecord {
  const AcpToolUpdateRecord({
    required super.sessionId,
    required this.isInitial,
    required this.toolCallId,
    required this.toolName,
    required this.hasKind,
    required this.title,
    required this.hasTitle,
    required this.status,
    required this.hasStatus,
    required this.output,
    required this.isFileMutation,
    required this.hasDiff,
  });

  final bool isInitial;
  final String? toolCallId;
  final String toolName;
  final bool hasKind;
  final String? title;
  final bool hasTitle;
  final PluginToolStatus status;
  final bool hasStatus;
  final String? output;
  final bool isFileMutation;
  final bool hasDiff;
}

class AcpPlanChangedRecord extends AcpSessionNotificationRecord {
  const AcpPlanChangedRecord({required super.sessionId});
}

class AcpAvailableCommandsChangedRecord extends AcpSessionNotificationRecord {
  const AcpAvailableCommandsChangedRecord({
    required super.sessionId,
    required this.commands,
  });

  final List<PluginCommand> commands;
}

class AcpSessionInfoChangedRecord extends AcpSessionNotificationRecord {
  const AcpSessionInfoChangedRecord({
    required super.sessionId,
    required this.hasTitle,
    required this.title,
    required this.updatedAtMs,
  });

  final bool hasTitle;
  final String? title;
  final int? updatedAtMs;
}

class AcpIgnoredSessionNotificationRecord extends AcpSessionNotificationRecord {
  const AcpIgnoredSessionNotificationRecord({required super.sessionId});
}

class AcpExtensionNotificationRecord extends AcpNotificationRecord {
  const AcpExtensionNotificationRecord({required this.method, required this.sessionId});

  final String method;

  @override
  final String? sessionId;
}

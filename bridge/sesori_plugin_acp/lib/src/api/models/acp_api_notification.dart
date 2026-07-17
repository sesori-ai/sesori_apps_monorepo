enum AcpApiMessageChunkRole { user, assistant, thought }

enum AcpApiToolStatus { pending, inProgress, completed, failed, unknown }

sealed class AcpApiNotification {
  const AcpApiNotification();
}

class AcpApiSessionNotification extends AcpApiNotification {
  const AcpApiSessionNotification({required this.sessionId, required this.update});

  final String sessionId;
  final AcpApiSessionUpdate update;
}

class AcpApiExtensionNotification extends AcpApiNotification {
  const AcpApiExtensionNotification({required this.method, required this.sessionId});

  final String method;
  final String? sessionId;
}

sealed class AcpApiSessionUpdate {
  const AcpApiSessionUpdate();
}

class AcpApiMessageChunkUpdate extends AcpApiSessionUpdate {
  const AcpApiMessageChunkUpdate({
    required this.role,
    required this.messageId,
    required this.text,
  });

  final AcpApiMessageChunkRole role;
  final String? messageId;
  final String? text;
}

class AcpApiToolUpdate extends AcpApiSessionUpdate {
  const AcpApiToolUpdate({
    required this.isInitial,
    required this.toolCallId,
    required this.kind,
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
  final String? kind;
  final String? title;
  final bool hasTitle;
  final AcpApiToolStatus status;
  final bool hasStatus;
  final String? output;
  final bool isFileMutation;
  final bool hasDiff;
}

class AcpApiPlanUpdate extends AcpApiSessionUpdate {
  const AcpApiPlanUpdate();
}

class AcpApiAvailableCommand {
  const AcpApiAvailableCommand({
    required this.name,
    required this.description,
    required this.hint,
  });

  final String name;
  final String? description;
  final String? hint;
}

class AcpApiAvailableCommandsUpdate extends AcpApiSessionUpdate {
  const AcpApiAvailableCommandsUpdate({required this.commands});

  final List<AcpApiAvailableCommand> commands;
}

class AcpApiSessionInfoUpdate extends AcpApiSessionUpdate {
  const AcpApiSessionInfoUpdate({
    required this.hasTitle,
    required this.title,
    required this.updatedAtMs,
  });

  final bool hasTitle;
  final String? title;
  final int? updatedAtMs;
}

class AcpApiIgnoredSessionUpdate extends AcpApiSessionUpdate {
  const AcpApiIgnoredSessionUpdate();
}

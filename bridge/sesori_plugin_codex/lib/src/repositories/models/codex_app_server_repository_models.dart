class CodexModelSelection {
  const CodexModelSelection({
    required this.providerId,
    required this.modelId,
  });

  final String providerId;
  final String modelId;
}

sealed class CodexTurnInput {
  const CodexTurnInput();
}

final class CodexTurnTextInput extends CodexTurnInput {
  const CodexTurnTextInput({required this.text});

  final String text;
}

final class CodexTurnLocalImageInput extends CodexTurnInput {
  const CodexTurnLocalImageInput({required this.path});

  final String path;
}

final class CodexTurnImageUrlInput extends CodexTurnInput {
  const CodexTurnImageUrlInput({required this.url});

  final String url;
}

class CodexThreadContextFacts {
  const CodexThreadContextFacts({
    required this.threadId,
    required this.model,
    required this.provider,
    required this.directory,
  });

  final String threadId;
  final String? model;
  final String? provider;
  final String? directory;
}

class CodexStartedThread {
  const CodexStartedThread({
    required this.id,
    required this.directory,
    required this.title,
    required this.createdAtSeconds,
    required this.updatedAtSeconds,
    required this.context,
  });

  final String id;
  final String? directory;
  final String? title;
  final num? createdAtSeconds;
  final num? updatedAtSeconds;
  final CodexThreadContextFacts context;
}

class CodexStartedTurn {
  const CodexStartedTurn({required this.id});

  final String id;
}

class CodexThreadNotFoundException implements Exception {
  const CodexThreadNotFoundException();
}

class CodexTurnAlreadyStoppedException implements Exception {
  const CodexTurnAlreadyStoppedException();
}

class CodexModelRecord {
  const CodexModelRecord({
    required this.id,
    required this.displayName,
    required this.hidden,
    required this.isDefault,
    required this.defaultReasoningEffort,
    required this.supportedReasoningEfforts,
  });

  final String? id;
  final String? displayName;
  final bool hidden;
  final bool isDefault;
  final String? defaultReasoningEffort;
  final List<String> supportedReasoningEfforts;
}

enum CodexThreadStatus { idle, busy }

enum CodexToolStatus { running, completed, error }

sealed class CodexItemRecord {
  const CodexItemRecord({required this.id});

  final String id;
}

final class CodexUserMessageItemRecord extends CodexItemRecord {
  const CodexUserMessageItemRecord({
    required super.id,
    required this.text,
  });

  final String? text;
}

final class CodexAgentMessageItemRecord extends CodexItemRecord {
  const CodexAgentMessageItemRecord({
    required super.id,
    required this.text,
  });

  final String? text;
}

final class CodexReasoningItemRecord extends CodexItemRecord {
  const CodexReasoningItemRecord({
    required super.id,
    required this.text,
  });

  final String? text;
}

final class CodexToolItemRecord extends CodexItemRecord {
  const CodexToolItemRecord({
    required super.id,
    required this.tool,
    required this.title,
    required this.status,
    required this.output,
    required this.error,
  });

  final String tool;
  final String? title;
  final CodexToolStatus status;
  final String? output;
  final String? error;
}

final class CodexUnsupportedItemRecord extends CodexItemRecord {
  const CodexUnsupportedItemRecord({required super.id});
}

sealed class CodexEventRecord {
  const CodexEventRecord({
    required this.threadId,
    required this.turnId,
    required this.context,
  });

  final String? threadId;
  final String? turnId;
  final CodexThreadContextFacts? context;
}

final class CodexThreadStartedEventRecord extends CodexEventRecord {
  const CodexThreadStartedEventRecord({
    required super.threadId,
    required this.thread,
    required super.context,
  }) : super(turnId: null);

  final CodexStartedThread? thread;
}

final class CodexThreadNameUpdatedEventRecord extends CodexEventRecord {
  const CodexThreadNameUpdatedEventRecord({
    required super.threadId,
    required this.threadName,
    required super.context,
  }) : super(turnId: null);

  final String? threadName;
}

final class CodexThreadStatusChangedEventRecord extends CodexEventRecord {
  const CodexThreadStatusChangedEventRecord({
    required super.threadId,
    required this.status,
    required super.context,
  }) : super(turnId: null);

  final CodexThreadStatus status;
}

final class CodexThreadClosedEventRecord extends CodexEventRecord {
  const CodexThreadClosedEventRecord({
    required super.threadId,
    required super.context,
  }) : super(turnId: null);
}

final class CodexTurnStartedEventRecord extends CodexEventRecord {
  const CodexTurnStartedEventRecord({
    required super.threadId,
    required super.turnId,
    required super.context,
  });
}

final class CodexTurnCompletedEventRecord extends CodexEventRecord {
  const CodexTurnCompletedEventRecord({
    required super.threadId,
    required super.turnId,
    required super.context,
  });
}

final class CodexItemEventRecord extends CodexEventRecord {
  const CodexItemEventRecord({
    required super.threadId,
    required super.turnId,
    required this.item,
    required super.context,
  });

  final CodexItemRecord? item;
}

final class CodexAgentMessageDeltaEventRecord extends CodexEventRecord {
  const CodexAgentMessageDeltaEventRecord({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.delta,
    required super.context,
  });

  final String? itemId;
  final String? delta;
}

final class CodexReasoningDeltaEventRecord extends CodexEventRecord {
  const CodexReasoningDeltaEventRecord({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.delta,
    required super.context,
  });

  final String? itemId;
  final String? delta;
}

final class CodexItemRemovedEventRecord extends CodexEventRecord {
  const CodexItemRemovedEventRecord({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required super.context,
  });

  final String? itemId;
}

final class CodexItemPartRemovedEventRecord extends CodexEventRecord {
  const CodexItemPartRemovedEventRecord({
    required super.threadId,
    required super.turnId,
    required this.itemId,
    required this.partId,
    required super.context,
  });

  final String? itemId;
  final String? partId;
}

final class CodexErrorEventRecord extends CodexEventRecord {
  const CodexErrorEventRecord({
    required super.threadId,
    required super.turnId,
    required super.context,
  });
}

final class CodexTurnDiffUpdatedEventRecord extends CodexEventRecord {
  const CodexTurnDiffUpdatedEventRecord({
    required super.threadId,
    required super.turnId,
    required super.context,
  });
}

final class CodexProjectChangedEventRecord extends CodexEventRecord {
  const CodexProjectChangedEventRecord() : super(threadId: null, turnId: null, context: null);
}

final class CodexIgnoredEventRecord extends CodexEventRecord {
  const CodexIgnoredEventRecord({
    required super.threadId,
    required super.turnId,
    required super.context,
  });
}

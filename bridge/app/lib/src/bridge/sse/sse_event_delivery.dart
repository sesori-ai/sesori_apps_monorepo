import "package:sesori_shared/sesori_shared.dart";

/// One outgoing SSE event, in every shape its subscribers may need.
///
/// Only message parts carrying bridge-owned images differ per subscriber; all
/// other events are one object for every connection.
sealed class const SseEventDelivery() {
  const factory uniform({required SesoriSseEvent event}) = UniformSseEventDelivery;

  const factory attachmentShaped({
    required SesoriSseEvent inlineEvent,
    required SesoriSseEvent storedReferenceEvent,
  }) = AttachmentShapedSseEventDelivery;

  /// The released shape, used by subscribers that predate stored attachment
  /// references and by bridge-local consumers.
  SesoriSseEvent get inlineEvent;

  SesoriSseEvent eventFor({required MessageAttachmentDelivery delivery});
}

final class const UniformSseEventDelivery({required final SesoriSseEvent event}) extends SseEventDelivery {
  @override
  SesoriSseEvent get inlineEvent => event;

  @override
  SesoriSseEvent eventFor({required MessageAttachmentDelivery delivery}) => inlineEvent;
}

final class const AttachmentShapedSseEventDelivery({
  @override required final SesoriSseEvent inlineEvent,
  required final SesoriSseEvent storedReferenceEvent,
}) extends SseEventDelivery {
  @override
  SesoriSseEvent eventFor({required MessageAttachmentDelivery delivery}) => switch (delivery) {
    MessageAttachmentDelivery.inline => inlineEvent,
    MessageAttachmentDelivery.storedReference => storedReferenceEvent,
  };
}

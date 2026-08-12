import "package:sesori_shared/sesori_shared.dart";

/// One outgoing SSE event, in every shape its subscribers may need.
///
/// Only message parts carrying bridge-owned images differ per subscriber; all
/// other events are one object for every connection.
sealed class SseEventDelivery {
  const SseEventDelivery();

  const factory SseEventDelivery.uniform({required SesoriSseEvent event}) = UniformSseEventDelivery;

  const factory SseEventDelivery.attachmentShaped({
    required SesoriSseEvent inlineEvent,
    required SesoriSseEvent storedReferenceEvent,
  }) = AttachmentShapedSseEventDelivery;

  /// The released shape, used by subscribers that predate stored attachment
  /// references and by bridge-local consumers.
  SesoriSseEvent get inlineEvent;

  SesoriSseEvent eventFor({required MessageAttachmentDelivery delivery});
}

final class UniformSseEventDelivery extends SseEventDelivery {
  @override
  final SesoriSseEvent inlineEvent;

  const UniformSseEventDelivery({required SesoriSseEvent event}) : inlineEvent = event;

  @override
  SesoriSseEvent eventFor({required MessageAttachmentDelivery delivery}) => inlineEvent;
}

final class AttachmentShapedSseEventDelivery extends SseEventDelivery {
  @override
  final SesoriSseEvent inlineEvent;
  final SesoriSseEvent storedReferenceEvent;

  const AttachmentShapedSseEventDelivery({
    required this.inlineEvent,
    required this.storedReferenceEvent,
  });

  @override
  SesoriSseEvent eventFor({required MessageAttachmentDelivery delivery}) => switch (delivery) {
    MessageAttachmentDelivery.inline => inlineEvent,
    MessageAttachmentDelivery.storedReference => storedReferenceEvent,
  };
}

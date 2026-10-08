import "openapi/assistant_message.g.dart";
import "openapi/text_part.g.dart";

/// What the live stream has shown of one compaction summary message: its
/// latest info, its latest text parts, and the `auto` flag of the compaction
/// marker it answers, when that marker was seen.
typedef SummaryMessage = ({AssistantMessage message, List<TextPart> textParts, bool? auto});

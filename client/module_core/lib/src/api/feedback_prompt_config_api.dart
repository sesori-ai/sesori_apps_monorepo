import "package:injectable/injectable.dart";

import "../foundation/platform/feedback_prompt_config_source.dart";

@lazySingleton
class FeedbackPromptConfigApi({required final FeedbackPromptConfigSource _source}) {
  Future<FeedbackPromptConfigValues> fetchValues() => _source.fetchValues();
}

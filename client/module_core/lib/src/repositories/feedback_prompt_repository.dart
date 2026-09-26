import "package:injectable/injectable.dart";

import "../api/feedback_prompt_config_api.dart";
import "../api/storage/feedback_prompt_storage.dart";
import "../foundation/models/feedback/feedback_prompt_config.dart";
import "../foundation/models/feedback/feedback_prompt_state.dart";

@lazySingleton
class FeedbackPromptRepository({
  required final FeedbackPromptConfigApi _configApi,
  required final FeedbackPromptStorage _storage,
}) {
  static const defaultInteractionThreshold = 10;
  static const defaultCooldownDays = 14;

  /// The remote rule, with the defaults for any value that is missing or below
  /// one. Firebase reports an unset key as zero, so a fallback is expected.
  Future<FeedbackPromptConfig> readConfig() async {
    final values = await _configApi.fetchValues();
    return FeedbackPromptConfig(
      interactionThreshold: _atLeastOne(value: values.interactionThreshold, fallback: defaultInteractionThreshold),
      cooldown: Duration(
        days: _atLeastOne(value: values.cooldownDays, fallback: defaultCooldownDays),
      ),
    );
  }

  /// This device's progress; a device that never stored any starts from zero.
  Future<FeedbackPromptState> readState() async =>
      await _storage.read() ?? const FeedbackPromptCounting(positiveCount: 0, lastShownAt: null);

  Future<void> writeState({required FeedbackPromptState state}) => _storage.write(state: state);
}

int _atLeastOne({required int? value, required int fallback}) => value != null && value >= 1 ? value : fallback;

import "package:flutter/widgets.dart";
import "package:sesori_motion_tuning/sesori_motion_tuning.dart";

import "feedback_flow_playbook.dart";
import "feedback_motion_spec.dart";

void main() => runApp(const FeedbackMotionTuningPlaybook());

/// Development-only entrypoint; scene replay and all feedback are simulated.
class const FeedbackMotionTuningPlaybook({super.key}) extends StatefulWidget {
  @override
  State<FeedbackMotionTuningPlaybook> createState() => _FeedbackMotionTuningPlaybookState();
}

class _FeedbackMotionTuningPlaybookState() extends State<FeedbackMotionTuningPlaybook> {
  MotionSnapshot _values = const MotionSnapshot();
  FeedbackMotionScene? _scene;
  int _revision = 0;

  void _replay({required MotionTarget target, required MotionSnapshot values}) {
    final scene = FeedbackMotionScene.values.byName(target.id);
    setState(() {
      _values = values;
      _scene = scene;
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) => MotionTuningHost(
    fixtureId: "feedback",
    targets: feedbackMotionTargets,
    onReplay: _replay,
    child: FeedbackMotionScope(
      values: _values,
      scene: _scene,
      revision: _revision,
      child: const FeedbackFlowPlaybook(openOnLaunch: true),
    ),
  );
}

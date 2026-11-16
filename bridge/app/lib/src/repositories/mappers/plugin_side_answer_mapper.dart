import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../models/side_question_ask_result.dart";

extension PluginSideAnswerMapper on PluginSideAnswer {
  SideQuestionAskResult toAskResult() => switch (this) {
    PluginSideAnswered(:final text, :final notice) => SideQuestionAnswered(text: text, notice: notice),
    PluginSideRefused(:final reason) => SideQuestionRefused(
      reason: switch (reason) {
        PluginSideRefusal.harnessUpdateRequired => SideQuestionRefusal.harnessUpdateRequired,
        PluginSideRefusal.noTurnYet => SideQuestionRefusal.noTurnYet,
        PluginSideRefusal.tooLong => SideQuestionRefusal.tooLong,
        PluginSideRefusal.noAnswer => SideQuestionRefusal.noAnswer,
        PluginSideRefusal.repeatedRunningReply => SideQuestionRefusal.repeatedRunningReply,
      },
    ),
  };
}

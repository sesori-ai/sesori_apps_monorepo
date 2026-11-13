import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Maps Oh My Pi's skill records to Sesori's skill kind.
///
/// OMP advertises each skill over ACP as a `skill:<name>` command, a name
/// prefix being the only thing that tells it apart from a command. Its replay
/// carries a skill run as a user turn in two shapes:
/// - OMP's own record, a custom message holding the injected skill prompt. The
///   ACP replay drops it when it is plain text, the shape a Sesori or text-only
///   run stores, and replays its text when the run carried an image.
/// - Pi's record, a `<skill name=… location=…>` envelope followed by the
///   arguments, which OMP replays verbatim for a session Pi wrote.
class const OmpSkillMapper() {
  static const String _skillPrefix = "skill:";

  static final RegExp _piSkillEnvelope = RegExp(
    r'^<skill name="([^"]+)" location="[^"]+">\n[\s\S]*\n</skill>(?:\n\n([\s\S]+))?$',
  );

  /// The notes Pi appends to a prompt after resizing, converting, or omitting
  /// its images.
  static final RegExp _piTrailingImageHints = RegExp(r"\n\n\[Image[^\n]*\](?:\n\[Image[^\n]*\])*$");

  /// OMP's `prompts/skills/user-invocation.md`, rendered and trimmed.
  static final RegExp _ompSkillPrompt = RegExp(
    r'^\[IMPORTANT: User invoked the "([^"]+)" skill; follow its instructions\. Full skill below\.\]\n'
    r"[\s\S]*\n\[Skill directory: [^\n]*\]\nResolve relative paths [^\n]*(?:\nUser: ([\s\S]+))?$",
  );

  /// [commands] with each `skill:<name>` command marked as a skill.
  List<PluginCommand> labelSkills({required List<PluginCommand> commands}) => [
    for (final command in commands)
      command.name.startsWith(_skillPrefix) ? command.copyWith(source: PluginCommandSource.skill) : command,
  ];

  /// [messages] with each replayed skill run named on its user turn, its text
  /// shown as `/skill:<name> args` rather than the injected skill body.
  List<PluginMessageWithParts> nameSkillRuns({required List<PluginMessageWithParts> messages}) => [
    for (final message in messages)
      switch ((message.info, message.parts.whereType<PluginMessagePartText>().singleOrNull)) {
        (final PluginMessageUser user, final text?) when user.invocation == null => switch (_skillRun(
          text: text.text,
        )) {
          (:final name, :final arguments) => _named(
            message: message,
            user: user,
            text: text,
            name: name,
            arguments: arguments,
          ),
          null => message,
        },
        _ => message,
      },
  ];

  ({String name, String? arguments})? _skillRun({required String text}) {
    final match =
        _ompSkillPrompt.firstMatch(text) ?? _piSkillEnvelope.firstMatch(text.replaceFirst(_piTrailingImageHints, ""));
    final name = match?.group(1);
    if (match == null || name == null) return null;
    return (name: "$_skillPrefix$name", arguments: match.group(2));
  }

  PluginMessageWithParts _named({
    required PluginMessageWithParts message,
    required PluginMessageUser user,
    required PluginMessagePartText text,
    required String name,
    required String? arguments,
  }) {
    return message.copyWith(
      info: user.copyWith(
        invocation: PluginCommandInvocation(name: name, source: PluginCommandSource.skill, arguments: arguments),
      ),
      parts: [
        for (final part in message.parts)
          identical(part, text) ? text.copyWith(text: arguments == null ? "/$name" : "/$name $arguments") : part,
      ],
    );
  }
}

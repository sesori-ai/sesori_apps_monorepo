/// What opens a dictated message, telling the agent to allow for misheard words.
const String _dictatedOpening = '🎙️ "';
const String _dictatedClosing = '"';

/// Marks [text] as dictated. Quotes inside [text] stay as they are, because
/// [unwrapDictatedText] removes only the outer pair. No words means no marker,
/// as for an attachment-only prompt.
String wrapDictatedText({required String text}) => text.isEmpty ? text : "$_dictatedOpening$text$_dictatedClosing";

/// The words [wrapDictatedText] marked, or [text] unchanged when it is not in
/// exactly that form.
String unwrapDictatedText({required String text}) {
  final isMarked =
      text.length > _dictatedOpening.length && text.startsWith(_dictatedOpening) && text.endsWith(_dictatedClosing);
  return isMarked ? text.substring(_dictatedOpening.length, text.length - _dictatedClosing.length) : text;
}

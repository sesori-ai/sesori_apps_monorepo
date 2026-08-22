import "dart:io";

/// [Stdout] that collects everything written to it.
///
/// Covers both `write` and `writeln` so a test can assert on either; every
/// other member is answered by [noSuchMethod] because `Stdout` is a large
/// interface and tests only ever exercise the writing surface.
class BufferingStdout() implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  /// Everything written so far, in order.
  String get text => _buffer.toString();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  // ignore: no_slop_linter/prefer_specific_type, Stdout's own signature
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// [Stdout] that appends each `writeln` to [lines] as a separate entry.
///
/// Use this instead of [BufferingStdout] when a test asserts on the number or
/// order of lines rather than on the whole text.
///
/// Unlike the other two fakes, an unimplemented member **throws** rather than
/// answering `null`. That is deliberate and matches the declarations this
/// replaced: a test asserting on exact line output wants to hear about an
/// unexpected call to something like `supportsAnsiEscapes`, whereas returning
/// `null` for a non-nullable getter would surface later as a confusing type
/// error far from the cause.
class CapturingStdout({required final List<String> lines}) implements Stdout {
  @override
  void writeln([Object? object = ""]) => lines.add(object.toString());

  @override
  // ignore: no_slop_linter/prefer_specific_type, Stdout's own signature
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

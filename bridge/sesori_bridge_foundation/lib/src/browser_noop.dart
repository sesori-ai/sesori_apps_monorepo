/// Internal browser-command contract shared by bridge entrypoint and plugins.
/// The entrypoint returns before bootstrap and never examines the URL argument.
abstract final class BrowserNoop() {
  static const argument = "--internal-browser-noop";

  static bool matches({required List<String> arguments}) => arguments.isNotEmpty && arguments.first == argument;
}

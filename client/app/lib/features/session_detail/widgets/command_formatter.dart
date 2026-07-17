import "package:sesori_shared/sesori_shared.dart";

abstract final class CommandFormatter {
  static String format(CommandMessageInfo command) {
    final arguments = command.arguments;
    return "/${command.name}${arguments == null || arguments.trim().isEmpty ? "" : " $arguments"}";
  }
}

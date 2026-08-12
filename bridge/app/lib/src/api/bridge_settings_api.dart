import 'dart:io';

class BridgeSettingsApi({String? homeDirectory}) {
  final String _homeDirectory = homeDirectory ?? _resolveHomeDirectory();

  String get configFilePath => '$_homeDirectory/.config/sesori/config.json';

  Future<String?> readConfig() async {
    final file = File(configFilePath);
    if (!file.existsSync()) {
      return null;
    }

    return await file.readAsString();
  }

  Future<void> writeConfig(String jsonContent) async {
    final directory = Directory('$_homeDirectory/.config/sesori');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    await File(configFilePath).writeAsString(jsonContent);
  }

  static String _resolveHomeDirectory() {
    final home = Platform.environment['HOME'];
    final userProfile = Platform.environment['USERPROFILE'];
    final homeDirectory = (home != null && home.isNotEmpty)
        ? home
        : (userProfile != null && userProfile.isNotEmpty)
        ? userProfile
        : null;
    if (homeDirectory == null) {
      throw StateError('Unable to determine home directory');
    }

    return homeDirectory;
  }
}

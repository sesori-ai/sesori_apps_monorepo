/// Maps a file path's extension to a [syntax_highlight] language name.
/// Returns null for unsupported or binary extensions.
String? detectLanguage({required String filePath}) {
  final ext = filePath.contains('.') ? filePath.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'dart' => 'dart',
    'ts' || 'tsx' => 'typescript',
    'js' || 'jsx' => 'javascript',
    'py' => 'python',
    'go' => 'go',
    'java' => 'java',
    'kt' || 'kts' => 'kotlin',
    'swift' => 'swift',
    'rs' => 'rust',
    'html' || 'htm' => 'html',
    'css' => 'css',
    'json' => 'json',
    'yaml' || 'yml' => 'yaml',
    'sql' => 'sql',
    _ => null,
  };
}

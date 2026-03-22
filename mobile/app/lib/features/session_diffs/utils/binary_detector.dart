/// Heuristic to detect binary files.
/// Checks extension first, then looks for null bytes in first 8KB of content.
bool isBinaryFile(String filePath, String content) {
  final ext = filePath.contains('.') ? filePath.split('.').last.toLowerCase() : '';
  const binaryExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'ico',
    'pdf',
    'zip',
    'tar',
    'gz',
    'exe',
    'bin',
    'wasm',
    'woff',
    'woff2',
    'ttf',
    'otf',
    'mp3',
    'mp4',
    'wav',
    'webp',
    'svg', // SVG is text-based XML but treat as binary for diff purposes
  };
  if (binaryExtensions.contains(ext)) return true;
  // Check for null bytes in first 8KB
  final sample = content.length > 8192 ? content.substring(0, 8192) : content;
  return sample.contains('\x00');
}

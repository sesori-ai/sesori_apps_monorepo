import "dart:io";

import "package:code_assets/code_assets.dart";
import "package:hooks/hooks.dart";

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets || input.config.code.targetOS != OS.macOS) return;
    final source = input.packageRoot.resolve("native/macos_power_observer.c");
    final library = input.outputDirectory.resolve("macos_power_observer.dylib");
    final result = await Process.run("clang", [
      "-dynamiclib",
      "-O2",
      "-framework",
      "IOKit",
      "-framework",
      "CoreFoundation",
      source.toFilePath(),
      "-o",
      library.toFilePath(),
    ]);
    if (result.exitCode != 0) throw StateError("macOS power observer build failed: ${result.stderr}");
    output.dependencies.add(source);
    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: "macos_power_observer.dylib",
        file: library,
        linkMode: DynamicLoadingBundled(),
      ),
    );
  });
}

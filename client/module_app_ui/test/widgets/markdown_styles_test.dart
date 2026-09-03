import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockUrlLauncher() extends Mock implements UrlLauncher;

void main() {
  final prego = PregoDesignSystem.light;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  test("buildSessionMarkdownStyleSheet applies shared code styling", () {
    final styleSheet = buildSessionMarkdownStyleSheet(prego: prego);

    expect(styleSheet.code?.fontFamily, "monospace");
    expect(styleSheet.code?.fontSize, 13);
    expect(styleSheet.code?.color, prego.colors.textPrimary);

    final decoration = styleSheet.codeblockDecoration as BoxDecoration?;
    expect(decoration?.color, prego.colors.bgQuaternary);
    expect(decoration?.borderRadius, BorderRadius.circular(8));
  });

  test("buildSessionMarkdownStyleSheet overrides paragraph style when provided", () {
    const paragraphStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

    final styleSheet = buildSessionMarkdownStyleSheet(prego: prego, paragraphStyle: paragraphStyle);

    expect(styleSheet.p, paragraphStyle);
  });

  test("buildUserMessageMarkdownStyleSheet keeps Markdown legible on the brand surface", () {
    final styleSheet = buildUserMessageMarkdownStyleSheet(prego: prego);

    expect(styleSheet.p?.color, prego.colors.textBrandPrimary);
    expect(styleSheet.a?.color, prego.colors.textBrandPrimary);
    expect(styleSheet.strong?.color, prego.colors.textBrandPrimary);
    expect(styleSheet.listBullet?.color, prego.colors.textBrandPrimary);
    expect(styleSheet.code?.color, prego.colors.textBrandPrimary);
  });

  test("sessionMarkdownBlockSyntaxes keeps raw HTML visible as a code block", () {
    const message =
        "Pi assistant response failed: <html>\n"
        "  <head>\n"
        "    <style>body{font-family:Arial}</style>\n"
        "  </head>\n"
        "  <body><p>Error 520</p></body>\n"
        "</html>";

    final nodes = md.Document(
      blockSyntaxes: sessionMarkdownBlockSyntaxes,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    ).parseLines(const LineSplitter().convert(message));

    final html = nodes.whereType<md.Element>().where((node) => node.tag == "pre").single;
    expect(html.textContent, contains("<head>"));
    expect(html.textContent, contains("Error 520"));
    expect(html.textContent, contains("</html>"));
  });

  test("Markdown links launch absolute web and email URLs", () async {
    final launcher = _MockUrlLauncher();
    when(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).thenAnswer((_) async => true);
    final handleLink = buildMarkdownLinkTapHandler(
      openExternalLink: ({required url, required mode}) => launcher.launch(url, mode: mode),
    );

    handleLink("web", "https://example.com/docs", "");
    handleLink("email", "mailto:help@example.com", "");
    await Future<void>.delayed(Duration.zero);

    verify(() => launcher.launch(Uri.parse("https://example.com/docs"), mode: UrlLaunchMode.externalApp)).called(1);
    verify(() => launcher.launch(Uri.parse("mailto:help@example.com"), mode: UrlLaunchMode.externalApp)).called(1);
  });

  test("Markdown links reject relative and custom-scheme URLs", () async {
    final launcher = _MockUrlLauncher();
    final handleLink = buildMarkdownLinkTapHandler(
      openExternalLink: ({required url, required mode}) => launcher.launch(url, mode: mode),
    );

    handleLink("relative", "/session/local", "");
    handleLink("custom", "sesori://session/secret", "");
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => launcher.launch(any(), mode: any(named: "mode")));
  });
}

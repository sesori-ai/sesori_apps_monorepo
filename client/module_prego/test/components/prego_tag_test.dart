import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets("PregoTag renders its label and optional icon", (tester) async {
    await tester.pumpWidget(
      _harness(const PregoTag(icon: TablerSolid.brand_github, label: "GitHub")),
    );

    expect(find.text("GitHub"), findsOneWidget);
    expect(find.byIcon(TablerSolid.brand_github), findsOneWidget);
  });

  testWidgets("PregoTag renders label-only without an icon slot", (tester) async {
    await tester.pumpWidget(_harness(const PregoTag(label: "Email")));

    expect(find.text("Email"), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets("PregoAvatarUser sizes itself and shows the user glyph", (tester) async {
    await tester.pumpWidget(_harness(const PregoAvatarUser()));

    expect(tester.getSize(find.byType(PregoAvatarUser)), const Size(40, 40));
    expect(find.byIcon(TablerRegular.user), findsOneWidget);
  });
}

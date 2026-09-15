import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("uses two words or two graphemes, including Unicode", (tester) async {
    for (final (name, initials) in [
      ("Sesori Desktop", "SD"),
      ("sesori", "SE"),
      ("S", "S"),
      ("👩‍💻 Tools", "👩‍💻T"),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          home: PregoAvatarInitials(label: name),
        ),
      );
      expect(find.text(initials), findsOneWidget);
    }
  });

  testWidgets("keeps the same palette colour on rebuild", (tester) async {
    Widget app() => MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.dark),
      home: const PregoAvatarInitials(label: "Sesori"),
    );
    await tester.pumpWidget(app());
    final color = tester.widget<Text>(find.text("SE")).style!.color;
    await tester.pumpWidget(app());
    expect(tester.widget<Text>(find.text("SE")).style!.color, color);
  });
}

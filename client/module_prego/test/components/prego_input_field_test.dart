import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

void main() {
  group("PregoInputField", () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    testWidgets("renders the label without an asterisk by default", (tester) async {
      await tester.pumpWidget(
        _harness(PregoInputField(controller: controller, label: "Email")),
      );

      expect(find.text("Email"), findsOneWidget);
    });

    testWidgets("appends a required marker to the label", (tester) async {
      await tester.pumpWidget(
        _harness(
          PregoInputField(controller: controller, label: "Email", isRequired: true),
        ),
      );

      // Label and marker share one Text.rich so screen readers announce them
      // together; assert on the flattened string rather than a separate node.
      expect(find.text("Email *", findRichText: true), findsOneWidget);
    });

    testWidgets("writes typed text into the controller", (tester) async {
      await tester.pumpWidget(
        _harness(PregoInputField(controller: controller, label: "Email")),
      );

      await tester.enterText(find.byType(TextFormField), "a@b.co");
      expect(controller.text, "a@b.co");
    });

    testWidgets("surfaces the validator message on form validation", (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _harness(
          Form(
            key: formKey,
            child: PregoInputField(
              controller: controller,
              label: "Email",
              validator: (value) => (value?.isEmpty ?? true) ? "Email is required" : null,
            ),
          ),
        ),
      );

      expect(find.text("Email is required"), findsNothing);

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.text("Email is required"), findsOneWidget);
    });

    testWidgets("obscureText hides the entered value", (tester) async {
      await tester.pumpWidget(
        _harness(
          PregoInputField(controller: controller, label: "Password", obscureText: true),
        ),
      );

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.obscureText, isTrue);
    });

    testWidgets("renders the trailing slot inside the field", (tester) async {
      await tester.pumpWidget(
        _harness(
          PregoInputField(
            controller: controller,
            label: "Password",
            trailing: const Icon(TablerRegular.eye),
          ),
        ),
      );

      expect(find.byIcon(TablerRegular.eye), findsOneWidget);
    });

    testWidgets("disabled fields reject input", (tester) async {
      await tester.pumpWidget(
        _harness(
          PregoInputField(controller: controller, label: "Email", enabled: false),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });
}

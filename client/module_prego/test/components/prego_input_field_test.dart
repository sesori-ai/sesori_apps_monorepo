import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
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

    testWidgets("renders the plain label and a tertiary placeholder", (tester) async {
      await tester.pumpWidget(
        _harness(PregoInputField(controller: controller, label: "Email", hintText: "you@example.com")),
      );

      expect(find.text("Email"), findsOneWidget);
      expect(find.textContaining("*"), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintStyle?.color, PregoDesignSystem.light.colors.textTertiary);
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

    testWidgets("does not flag an invalid first pass mid-typing, then revalidates after submit", (tester) async {
      final formKey = GlobalKey<FormState>();
      String? validate(String? value) =>
          (value == null || !value.contains("@")) ? "Invalid email" : null;

      await tester.pumpWidget(
        _harness(
          Form(
            key: formKey,
            child: PregoInputField(controller: controller, label: "Email", validator: validate),
          ),
        ),
      );

      // Typing an incomplete value before any submit must not scold the user.
      await tester.enterText(find.byType(TextFormField), "alex");
      await tester.pump();
      expect(find.text("Invalid email"), findsNothing);

      // The submit-time validate() raises the error.
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text("Invalid email"), findsOneWidget);

      // Once errored, the field revalidates as the user fixes it — no second
      // submit needed to clear the message.
      await tester.enterText(find.byType(TextFormField), "alex@example.com");
      await tester.pump();
      expect(find.text("Invalid email"), findsNothing);
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

import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/app.dart";

void main() {
  testWidgets("SesoriDesktopApp renders the placeholder window", (WidgetTester tester) async {
    await tester.pumpWidget(const SesoriDesktopApp());

    expect(find.text("Sesori"), findsOneWidget);
  });
}

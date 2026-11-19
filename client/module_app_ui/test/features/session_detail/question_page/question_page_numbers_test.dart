import "package:flutter_test/flutter_test.dart";
import "package:sesori_app_ui/src/features/session_detail/question_page/question_page_numbers.dart";
import "package:sesori_shared/sesori_shared.dart";

PageQuestion _question(String id) =>
    PageQuestion(id: id, title: id, body: null, images: const [], kind: const PageTextInput(), isRequired: false);

PageSection _section({required String? heading, required List<String> questions}) => PageSection(
  heading: heading,
  body: null,
  images: const [],
  questions: [for (final id in questions) _question(id)],
);

void main() {
  test("a page without headings numbers its questions plainly", () {
    expect(
      questionPageNumbers(
        sections: [
          _section(heading: null, questions: ["a", "b", "c"]),
        ],
      ),
      [
        ["1", "2", "3"],
      ],
    );
  });

  test("a single section of questions numbers them plainly around sections without questions", () {
    expect(
      questionPageNumbers(
        sections: [
          _section(heading: "Background", questions: []),
          _section(heading: "Choices", questions: ["a", "b"]),
          _section(heading: "Notes", questions: []),
        ],
      ),
      [
        <String>[],
        ["1", "2"],
        <String>[],
      ],
    );
  });

  test("numbers restart in each section holding questions, counting only those", () {
    expect(
      questionPageNumbers(
        sections: [
          _section(heading: "Dismissing", questions: ["a", "b"]),
          _section(heading: "Background", questions: []),
          _section(heading: "Notes", questions: ["c"]),
        ],
      ),
      [
        ["1.1", "1.2"],
        <String>[],
        ["2.1"],
      ],
    );
  });

  test("questions before the first heading form their own leading section", () {
    expect(
      questionPageNumbers(
        sections: [
          _section(heading: null, questions: ["a"]),
          _section(heading: "Notes", questions: ["b", "c"]),
        ],
      ),
      [
        ["1.1"],
        ["2.1", "2.2"],
      ],
    );
  });

  test("a part without a heading continues the section above it", () {
    expect(
      questionPageNumbers(
        sections: [
          _section(heading: "Dismissing", questions: ["a"]),
          _section(heading: null, questions: ["b"]),
          _section(heading: "Notes", questions: ["c"]),
        ],
      ),
      [
        ["1.1"],
        ["1.2"],
        ["2.1"],
      ],
    );
  });
}

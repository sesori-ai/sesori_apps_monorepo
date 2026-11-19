import "package:sesori_shared/sesori_shared.dart";

/// The numbers of the questions on a page made of [sections]: the result's
/// `[i][j]` numbers question `j` of `sections[i]`.
///
/// Each heading starts a section, and questions before the first heading form
/// their own leading one. Sections holding questions are numbered 1, 2, 3 in
/// page order, and their questions restart at 1 inside each: "1.1", "2.1".
/// A page with a single section of questions numbers them plainly: "1", "2".
List<List<String>> questionPageNumbers({required List<PageSection> sections}) {
  final places = <List<({int section, int question})>>[];
  var sectionNumber = 0;
  var questionNumber = 0;
  var startsSection = true;
  for (final section in sections) {
    if (section.heading != null) startsSection = true;
    final row = <({int section, int question})>[];
    for (final _ in section.questions) {
      if (startsSection) {
        sectionNumber++;
        questionNumber = 0;
        startsSection = false;
      }
      questionNumber++;
      row.add((section: sectionNumber, question: questionNumber));
    }
    places.add(row);
  }
  final nested = sectionNumber > 1;
  return [
    for (final row in places)
      [for (final place in row) nested ? "${place.section}.${place.question}" : "${place.question}"],
  ];
}

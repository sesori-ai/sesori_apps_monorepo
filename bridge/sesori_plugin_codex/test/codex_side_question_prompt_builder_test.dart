import "dart:convert";

import "package:codex_plugin/src/services/codex_side_question_prompt_builder.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const builder = CodexSideQuestionPromptBuilder();
  const instruction =
      "Answer the side question from what you already know about this conversation. "
      "Do not use tools. Reply with text only.";

  int bytes(String value) => utf8.encode(value).length;

  test("a question without history is the question and the instruction", () {
    expect(builder.build(question: "Why?", history: const []), "Side question: Why?\n\n$instruction");
  });

  test("earlier exchanges come first, oldest first, labelled as outside the main conversation", () {
    final prompt = builder.build(
      question: "And then?",
      history: const [
        PluginSideExchange(question: "First?", answer: "One."),
        PluginSideExchange(question: "Second?", answer: "Two."),
      ],
    );

    expect(
      prompt,
      "Earlier side questions about this conversation, oldest first. "
      "They are not part of the main conversation.\n"
      "\n"
      "Question: First?\n"
      "Answer: One.\n"
      "\n"
      "Question: Second?\n"
      "Answer: Two.\n"
      "\n"
      "Side question: And then?\n"
      "\n"
      "$instruction",
    );
  });

  test("over the budget, the oldest exchanges are dropped and the oldest kept answer is shortened", () {
    final history = [
      for (var i = 0; i < 6; i++) PluginSideExchange(question: "Old $i?", answer: "${"x" * 900} end $i."),
      const PluginSideExchange(question: "Newest?", answer: "Newest answer."),
    ];

    final prompt = builder.build(question: "Now?", history: history);

    expect(prompt, isNotNull);
    final text = prompt ?? "";
    expect(bytes(text), lessThanOrEqualTo(CodexSideQuestionPromptBuilder.maxBytes));
    expect(text, isNot(contains("Old 0?")));
    expect(text, isNot(contains("Old 1?")));
    // The oldest kept exchange keeps its question and loses the end of its answer.
    expect(text, contains("Question: Old 2?"));
    expect(text, isNot(contains("end 2.")));
    expect(text, contains("x…\n"));
    expect(text, contains("end 3."));
    expect(text, contains("end 4."));
    expect(text, contains("end 5."));
    expect(text, contains("Answer: Newest answer."));
    expect(text, endsWith("Side question: Now?\n\n$instruction"));
  });

  test("shortening never splits a multi-byte character", () {
    final prompt = builder.build(
      question: "Now?",
      history: [PluginSideExchange(question: "Emoji?", answer: "😀" * 1500)],
    );

    final text = prompt ?? "";
    expect(bytes(text), lessThanOrEqualTo(CodexSideQuestionPromptBuilder.maxBytes));
    expect(text, contains("😀…"));
    expect(text, isNot(contains("�")));
  });

  test("an exchange too long to shorten is dropped whole", () {
    final prompt = builder.build(
      question: "Now?",
      history: [PluginSideExchange(question: "q" * 4000, answer: "Short.")],
    );

    expect(prompt, "Side question: Now?\n\n$instruction");
  });

  test("a question that cannot fit on its own has no prompt", () {
    expect(builder.build(question: "x" * CodexSideQuestionPromptBuilder.maxBytes, history: const []), isNull);
  });
}

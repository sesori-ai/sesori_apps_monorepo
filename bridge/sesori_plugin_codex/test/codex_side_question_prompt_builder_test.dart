import "dart:convert";

import "package:codex_plugin/src/services/codex_side_question_prompt_builder.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const builder = CodexSideQuestionPromptBuilder();
  const instruction =
      "Answer the side question from what you already know about this conversation. "
      "Do not use tools. Reply with text only.";

  const cap = 4000;

  int bytes(String value) => utf8.encode(value).length;

  test("a question without history is the question and the instruction", () {
    expect(builder.build(question: "Why?", history: const [], maxBytes: cap), "Side question: Why?\n\n$instruction");
  });

  test("earlier exchanges come first, oldest first, labelled as outside the main conversation", () {
    final prompt = builder.build(
      question: "And then?",
      history: const [
        PluginSideExchange(question: "First?", answer: "One."),
        PluginSideExchange(question: "Second?", answer: "Two."),
      ],
      maxBytes: cap,
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

    final prompt = builder.build(question: "Now?", history: history, maxBytes: cap);

    expect(prompt, isNotNull);
    final text = prompt ?? "";
    expect(bytes(text), lessThanOrEqualTo(cap));
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
      maxBytes: cap,
    );

    final text = prompt ?? "";
    expect(bytes(text), lessThanOrEqualTo(cap));
    expect(text, contains("😀…"));
    expect(text, isNot(contains("�")));
  });

  test("an exchange too long to shorten is dropped whole", () {
    final prompt = builder.build(
      question: "Now?",
      history: [PluginSideExchange(question: "q" * 4000, answer: "Short.")],
      maxBytes: cap,
    );

    expect(prompt, "Side question: Now?\n\n$instruction");
  });

  test("a question that cannot fit on its own has no prompt", () {
    expect(builder.build(question: "x" * cap, history: const [], maxBytes: cap), isNull);
  });

  test("without a cap, every exchange and the whole question are kept", () {
    final history = [
      for (var i = 0; i < 6; i++) PluginSideExchange(question: "Old $i?", answer: "${"x" * 900} end $i."),
    ];
    final question = "y" * cap;

    final text = builder.build(question: question, history: history, maxBytes: null) ?? "";

    expect(bytes(text), greaterThan(cap));
    for (var i = 0; i < 6; i++) {
      expect(text, contains("Question: Old $i?\nAnswer: ${"x" * 900} end $i.\n"));
    }
    expect(text, isNot(contains("…")));
    expect(text, endsWith("Side question: $question\n\n$instruction"));
  });
}

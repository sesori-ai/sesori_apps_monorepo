import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolDefinition;

/// The page tools Sesori's MCP server offers.
enum PageTool({
  required final String wireName,
  required final String description,

  /// Advertised as MCP's `readOnlyHint`.
  required final bool readOnly,

  /// The JSON Schema of the tool's arguments, as MCP's `inputSchema`.
  required final Map<String, Object?> inputSchema,
}) {
  sendPage(
    wireName: "send_page",
    readOnly: true,
    description:
        "Ask the user on a page in the Sesori app, on whichever device they pick up: for decisions, choices "
        "between options, or input you need from them, especially several questions at once or anything that "
        "needs images. Also shows information that needs no answer. Returns at once; Sesori messages this "
        "session with the user's answers, or that they closed the page, so don't wait or poll for it, and don't "
        "ask the same thing in chat too. A page has sections, each with an optional heading, a Markdown body, "
        "images and questions. Question kinds: single (pick one option), multiple (pick any options) or text "
        "(free text). Sesori gives every question its own note field and ends every page with a free-text "
        '"Anything else?" field, so do not add your own catch-all question such as "Anything else?" or '
        '"Other comments". '
        "Images are absolute paths to png, jpg, gif or webp files, copied when sent. Limits: title 200 "
        "characters, 20 images (20 MiB each, 50 MiB in all), 50 questions, 12 options per question. "
        "Question ids are unique in the page and option ids in their question.",
    inputSchema: {
      "type": "object",
      "properties": {
        "title": {"type": "string"},
        "intro": {"type": "string", "description": "Markdown under the title."},
        "sections": {"type": "array", "items": _pageSectionSchema},
      },
      "required": ["title", "sections"],
      "additionalProperties": false,
    },
  );

  SesoriToolDefinition get definition =>
      SesoriToolDefinition(name: wireName, description: description, readOnly: readOnly, inputSchema: inputSchema);
}

const Map<String, Object?> _pageImageSchema = {
  "type": "object",
  "properties": {
    "path": {"type": "string", "description": "Absolute path."},
    "caption": {"type": "string"},
  },
  "required": ["path"],
  "additionalProperties": false,
};

const Map<String, Object?> _pageImagesSchema = {"type": "array", "items": _pageImageSchema};

const Map<String, Object?> _pageOptionSchema = {
  "type": "object",
  "properties": {
    "id": {"type": "string"},
    "label": {"type": "string"},
    "description": {"type": "string", "description": "Markdown."},
    "image": _pageImageSchema,
    "recommended": {"type": "boolean", "description": "Shows a label; never preselected."},
  },
  "required": ["id", "label"],
  "additionalProperties": false,
};

const Map<String, Object?> _pageQuestionSchema = {
  "type": "object",
  "properties": {
    "id": {"type": "string"},
    "title": {"type": "string"},
    "body": {"type": "string", "description": "Markdown."},
    "images": _pageImagesSchema,
    "kind": {
      "type": "string",
      "enum": ["single", "multiple", "text"],
    },
    "options": {
      "type": "array",
      "items": _pageOptionSchema,
      "description": "single and multiple only.",
    },
    "required": {"type": "boolean", "description": "Must be answered to submit; false by default."},
  },
  "required": ["id", "title", "kind"],
  "additionalProperties": false,
};

const Map<String, Object?> _pageSectionSchema = {
  "type": "object",
  "properties": {
    "heading": {"type": "string"},
    "body": {"type": "string", "description": "Markdown."},
    "images": _pageImagesSchema,
    "questions": {
      "type": "array",
      "items": _pageQuestionSchema,
      "description": 'No catch-all "Anything else?" question: the page already ends with one.',
    },
  },
  "additionalProperties": false,
};

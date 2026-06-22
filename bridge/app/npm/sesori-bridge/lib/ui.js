"use strict";

// Presentation layer for the npm bootstrap. This is the Node.js implementation of
// the SAME visual spec used by install.sh and install.ps1 — banner, colored
// steps, progress bar, completion panel, and labeled error/warning prefixes are
// kept byte-for-byte equivalent across the three runtimes.
//
// Color and Unicode are opt-out: we degrade to plain ASCII whenever the
// environment can't be trusted to render them (NO_COLOR, redirected output,
// TERM=dumb, non-UTF-8 locale). FORCE_COLOR forces color on.

var TOTAL_STEPS = 4;
var PANEL_WIDTH = 56;
var ESC = "\u001b";

// ┌─ PALETTE ───────────────────────────────────────────────────────────────────
// │ Edit these ANSI codes in ONE place to retheme the installer. They map into the
// │ active palette only when color is enabled.
// │ 256-color codes: brand blue #1472FF ≈ 39 (bright) / 25 (deep).
// └──────────────────────────────────────────────────────────────────────────────
var PALETTE = {
  reset: ESC + "[0m",
  banner: ESC + "[0;2m", // SESORI wordmark — faded grey
  brand: ESC + "[38;5;39m", // accents: step counter, command, progress bar
  brandDim: ESC + "[38;5;25m",
  green: ESC + "[38;5;42m", // success
  yellow: ESC + "[38;5;214m", // warning
  red: ESC + "[38;5;203m", // error
  dim: ESC + "[0;2m", // secondary / muted text
  bold: ESC + "[1m",
};

var BANNER_UNICODE = [
  " \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2557",
  " \u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2588\u2588\u2554\u2550\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2551",
  " \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2551   \u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2551",
  " \u255a\u2550\u2550\u2550\u2550\u2588\u2588\u2551\u2588\u2588\u2554\u2550\u2550\u255d  \u255a\u2550\u2550\u2550\u2550\u2588\u2588\u2551\u2588\u2588\u2551   \u2588\u2588\u2551\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2551",
  " \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551\u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u255d\u2588\u2588\u2551  \u2588\u2588\u2551\u2588\u2588\u2551",
  " \u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u255a\u2550\u2550\u2550\u2550\u2550\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u2550\u255d \u255a\u2550\u255d  \u255a\u2550\u255d\u255a\u2550\u255d",
];

var BANNER_ASCII = [
  "  ____  _____ ____   ___  ____  ___ ",
  " / ___|| ____/ ___| / _ \\|  _ \\|_ _|",
  " \\___ \\|  _| \\___ \\| | | | |_) || | ",
  "  ___) | |___ ___) | |_| |  _ < | | ",
  " |____/|_____|____/ \\___/|_| \\_\\___|",
];

function Ui(options) {
  options = options || {};
  var stream = options.stream || process.stdout;
  var errStream = options.errStream || process.stderr;

  this._stream = stream;
  this._errStream = errStream;
  this._useColor = detectColor(stream, options.env || process.env);
  this._useUnicode = detectUnicode(options.env || process.env);

  // Active palette: real codes when color is on, empty strings otherwise.
  var p = this._useColor ? PALETTE : emptyPalette();
  this._c = p;

  this._glyphs = this._useUnicode
    ? {
        check: "\u2713", // ✓
        warn: "\u26a0", // ⚠
        cross: "\u2717", // ✗
        arrow: "\u279c", // ➜
        barFull: "\u25a0", // ■
        barEmpty: "\uff65", // ･
      }
    : {
        check: "[OK]",
        warn: "!",
        cross: "x",
        arrow: ">",
        barFull: "#",
        barEmpty: ".",
      };
}

function emptyPalette() {
  return {
    reset: "",
    banner: "",
    brand: "",
    brandDim: "",
    green: "",
    yellow: "",
    red: "",
    dim: "",
    bold: "",
  };
}

// Color is emitted unless NO_COLOR is set, output is not a TTY, or TERM=dumb.
// FORCE_COLOR forces it on.
function detectColor(stream, env) {
  if (env.FORCE_COLOR) {
    return true;
  }
  if (env.NO_COLOR) {
    return false;
  }
  if (!stream || !stream.isTTY) {
    return false;
  }
  if (!env.TERM || env.TERM === "dumb") {
    return false;
  }
  return true;
}

// Unicode glyphs are safe in a UTF-8 locale; otherwise fall back to ASCII. On
// Windows, Node's console is UTF-8-capable, so default to Unicode unless the
// locale clearly says otherwise.
function detectUnicode(env) {
  if (env.TERM === "dumb") {
    return false;
  }
  var locale = env.LC_ALL || env.LC_CTYPE || env.LANG || "";
  if (/utf-?8/i.test(locale)) {
    return true;
  }
  if (process.platform === "win32" && !locale) {
    return true;
  }
  return false;
}

Ui.prototype.useColor = function() {
  return this._useColor;
};

Ui.prototype.useUnicode = function() {
  return this._useUnicode;
};

Ui.prototype.glyphs = function() {
  return this._glyphs;
};

Ui.prototype._write = function(line) {
  this._stream.write(line + "\n");
};

Ui.prototype._writeErr = function(line) {
  this._errStream.write(line + "\n");
};

// Wrap text in a color (and reset), or pass it through when color is off.
Ui.prototype.paint = function(color, text) {
  if (this._useColor && color) {
    return color + text + this._c.reset;
  }
  return text;
};

// The SESORI wordmark, faded grey, printed as the header.
Ui.prototype.banner = function() {
  var b = this._useColor ? this._c.banner : "";
  var r = this._useColor ? this._c.reset : "";
  var lines = this._useUnicode ? BANNER_UNICODE : BANNER_ASCII;
  this._write("");
  for (var i = 0; i < lines.length; i++) {
    this._write(b + lines[i] + r);
  }
  this._write("");
  this._write(
    "  " +
      this.paint(
        this._c.dim,
        "Installing the Sesori Bridge \u2014 connect AI coding sessions to your phone"
      )
  );
  this._write("");
};

// Two muted summary lines under the banner.
Ui.prototype.summary = function(platform, version) {
  this._write(
    "  " + this.paint(this._c.dim, "Platform") + " " + this.paint(this._c.bold, platform)
  );
  this._write(
    "  " + this.paint(this._c.dim, "Version ") + " " + this.paint(this._c.bold, version)
  );
  this._write("");
};

// A "[n/N] message" step header in brand blue.
Ui.prototype.step = function(number, message) {
  this._write(this.paint(this._c.brand, "[" + number + "/" + TOTAL_STEPS + "]") + " " + message);
};

// A green success line with a check glyph, confirming a completed step.
Ui.prototype.ok = function(message) {
  this._write(
    "      " + this.paint(this._c.green, this._glyphs.check) + " " + this.paint(this._c.dim, message)
  );
};

// A muted, indented note under a step.
Ui.prototype.note = function(message) {
  this._write("      " + this.paint(this._c.dim, message));
};

// A muted note emitted to stderr (for diagnostics like lock-wait that should not
// pollute stdout but must remain visible when stdout is redirected).
Ui.prototype.noteErr = function(message) {
  this._writeErr(this.paint(this._c.dim, message));
};

// Error / warning / note prefixes. All go to stderr so they remain visible when
// stdout is redirected.
Ui.prototype.error = function(message) {
  this._writeErr(this.paint(this._c.red, this._glyphs.cross + " Error:") + " " + message);
};

Ui.prototype.warn = function(message) {
  this._writeErr(this.paint(this._c.yellow, this._glyphs.warn + " Warning:") + " " + message);
};

Ui.prototype.hint = function(message) {
  this._writeErr(this.paint(this._c.brand, this._glyphs.arrow + " Note:") + " " + message);
};

function repeat(ch, count) {
  if (count <= 0) {
    return "";
  }
  return new Array(count + 1).join(ch);
}

Ui.prototype._panelChars = function() {
  if (this._useUnicode) {
    return { tl: "\u250c", tr: "\u2510", bl: "\u2514", br: "\u2518", h: "\u2500", v: "\u2502" };
  }
  return { tl: "+", tr: "+", bl: "+", br: "+", h: "-", v: "|" };
};

Ui.prototype.panelTop = function(border) {
  var c = this._panelChars();
  this._write("  " + border + c.tl + repeat(c.h, PANEL_WIDTH) + c.tr + this._c.reset);
};

Ui.prototype.panelBottom = function(border) {
  var c = this._panelChars();
  this._write("  " + border + c.bl + repeat(c.h, PANEL_WIDTH) + c.br + this._c.reset);
};

// A single panel row. Content longer than the inner width is truncated with an
// ellipsis so the right border stays aligned.
Ui.prototype.panelRow = function(content, contentColor, border) {
  content = content || "";
  var c = this._panelChars();
  var inner = PANEL_WIDTH - 2;
  if (content.length > inner) {
    if (this._useUnicode) {
      content = content.slice(0, inner - 1) + "\u2026";
    } else {
      content = content.slice(0, inner - 3) + "...";
    }
  }
  var pad = inner - content.length;
  if (pad < 0) {
    pad = 0;
  }
  var painted = contentColor ? this.paint(contentColor, content) : content;
  this._write(
    "  " + border + c.v + this._c.reset + " " + painted + repeat(" ", pad) + " " + border + c.v + this._c.reset
  );
};

// A panel row highlighting a runnable command plus a muted inline comment. Width
// is computed from the plain text so colored escapes don't skew alignment. If the
// command alone exceeds the panel width the comment is dropped (and the command
// truncated as a last resort) so the right border stays aligned.
Ui.prototype.panelCommandRow = function(command, comment, border) {
  var c = this._panelChars();
  var gap = "   ";
  var inner = PANEL_WIDTH - 2;
  var ellipsis = this._useUnicode ? "\u2026" : "...";

  // Drop the comment if command + gap + comment overflows.
  if (command.length + gap.length + comment.length > inner) {
    comment = "";
  }
  // Truncate the command itself if it still overflows on its own.
  if (command.length > inner) {
    command = command.slice(0, inner - ellipsis.length) + ellipsis;
  }

  var plain = comment ? command + gap + comment : command;
  var pad = inner - plain.length;
  if (pad < 0) {
    pad = 0;
  }
  var painted = comment
    ? this.paint(this._c.brand + this._c.bold, command) + gap + this.paint(this._c.dim, comment)
    : this.paint(this._c.brand + this._c.bold, command);
  this._write(
    "  " + border + c.v + this._c.reset + " " + painted + repeat(" ", pad) + " " + border + c.v + this._c.reset
  );
};

// A panel row with an emphasized middle segment: prefix + bold(emphasis) + suffix.
Ui.prototype.panelEmphasisRow = function(prefix, emphasis, suffix, border) {
  var c = this._panelChars();
  var plain = prefix + emphasis + suffix;
  var inner = PANEL_WIDTH - 2;
  var pad = inner - plain.length;
  if (pad < 0) {
    pad = 0;
  }
  var painted = prefix + this.paint(this._c.brand + this._c.bold, emphasis) + suffix;
  this._write(
    "  " + border + c.v + this._c.reset + " " + painted + repeat(" ", pad) + " " + border + c.v + this._c.reset
  );
};

// Quiet success confirmation + boxed "Next steps" call-to-action. onPath controls
// whether the "open a new terminal" instruction is shown.
Ui.prototype.completion = function(options) {
  var version = options.version;
  var location = options.location;
  var onPath = options.onPath;
  var command = options.command || "sesori-bridge";

  this._write("");
  this._write(this.paint(this._c.green, this._glyphs.check) + " Sesori Bridge v" + version + " installed");
  this._write(this.paint(this._c.dim, "Location") + " " + this.paint(this._c.dim, location));
  this._write("");

  var border = this._c.brand;
  var comment = "# Start the bridge";
  var gap = "   ";
  var inner = PANEL_WIDTH - 2;
  // A runnable command must stay intact (copy/paste-able). If it fits a panel
  // row inside the box, keep the polished boxed layout; otherwise render the
  // full, un-truncated command on its own line BELOW the box so a long managed
  // path or long forwarded args are never ellipsized.
  var fitsInBox = command.length + gap.length + comment.length <= inner;

  this.panelTop(border);
  this.panelRow("Next steps", this._c.bold, border);
  this.panelRow("", "", border);
  if (!onPath) {
    this.panelEmphasisRow("In a ", "new terminal", " window, run:", border);
    if (fitsInBox) {
      this.panelRow("", "", border);
    }
  }
  if (fitsInBox) {
    this.panelCommandRow(command, comment, border);
  }
  this.panelBottom(border);

  if (!fitsInBox) {
    // Full command on its own line, never truncated.
    this._write("");
    this._write("    " + this.paint(this._c.brand + this._c.bold, command));
  }
  this._write("");
};

// Render an in-place download progress bar (brand-blue ■/･ + percentage). No-op
// when color is off or output is not a TTY, so logs stay clean.
Ui.prototype.progress = function(received, total) {
  if (!this._useColor || !this._stream.isTTY || !total || total <= 0) {
    return;
  }
  var width = 32;
  var percent = Math.floor((received * 100) / total);
  if (percent > 100) {
    percent = 100;
  }
  var on = Math.floor((percent * width) / 100);
  var off = width - on;
  var bar =
    this._c.brand +
    repeat(this._glyphs.barFull, on) +
    this._c.dim +
    repeat(this._glyphs.barEmpty, off) +
    this._c.reset;
  var pct = ("   " + percent).slice(-3);
  this._stream.write("\r      " + bar + " " + pct + "%");
};

// Finish the progress line (newline) if a bar was being drawn.
Ui.prototype.progressDone = function() {
  if (this._useColor && this._stream.isTTY) {
    this._stream.write("\n");
  }
};

// Process-wide shared instance, so low-level modules can emit styled
// warnings/notes without each constructing their own (and re-detecting).
var sharedInstance = null;
function shared() {
  if (!sharedInstance) {
    sharedInstance = new Ui({});
  }
  return sharedInstance;
}

module.exports = {
  Ui: Ui,
  shared: shared,
  TOTAL_STEPS: TOTAL_STEPS,
  PANEL_WIDTH: PANEL_WIDTH,
  detectColor: detectColor,
  detectUnicode: detectUnicode,
};

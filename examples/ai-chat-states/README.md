# AI chat flow demo

An interactive design reference for the three stages of an AI chat turn: thinking, working, and finished results. This is the recovered standalone HTML/CSS/JavaScript prototype, including its later local refinements.

[View the source design in Figma](https://www.figma.com/design/DTKWZawsS3zfA7TPA4OlGr/PREGO-Design-System?node-id=4967-3475)

## Open the demo

After checking out this branch, run from the repository root:

```sh
python3 -m http.server 4186 --bind 127.0.0.1 --directory examples/ai-chat-states
```

Open [the demo in your browser](http://127.0.0.1:4186/). No build, dependency installation, or backend is needed. The entire folder can also be copied and served independently; images and fonts are included.

## Explore

- Compare Thinking, Working, and Result side by side. Scroll horizontally on a narrow window.
- Expand the tool activity, commands, image previews, and subagent groups.
- Expand the finished workspace with “Worked for 5 min 15s”.
- Click file names to open a preview sheet; close it with the close button or Escape.
- Try the command copy buttons and the animated working timer.

The content is fixed demonstration data. Response branching, the feedback link, and other presentation-only controls do not connect to the product. This is inspiration for interaction and motion, not a production chat client. The preserved prototype includes reduced-motion handling.

## Files

- `index.html`: chat states and sample content.
- `styles.css`: layout, typography, colors, and motion.
- `script.js`: disclosures, file sheets, copy actions, and timers.
- `assets/`: the original Figma images and repository fonts, with their license notices.

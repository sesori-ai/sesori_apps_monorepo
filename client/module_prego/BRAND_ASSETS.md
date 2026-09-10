# Brand Asset Sources

## Antigravity

`assets/svgs/brands/antigravity.svg` is the owner-supplied full-colour
Antigravity mark, retained unchanged and used only to identify Antigravity.
Source SHA-256: `1e7f9ad3f5495e83ba011a84f61cf18178f0975cdf6ee5a0dddb1e01da1d529e`.

Flutter's SVG compiler does not implement its Gaussian blur filters, so the
widget uses `assets/images/brands/antigravity.png`, a transparent 452×452
render of that source. Both themes use the same colours and geometry.
PNG SHA-256: `29f646b6c37e3a67f9ab38695e75995e9e5c042410405c78aa72a5b484bda8c3`.

Regenerate from the repository root:

```python
from pathlib import Path
import subprocess

source = Path("client/module_prego/assets/svgs/brands/antigravity.svg").read_text()
# resvg uses luminance masks: white preserves this opaque alpha silhouette.
# This rendering-only adaptation does not modify the source SVG.
source = source.replace('<path fill="#000"', '<path fill="#fff"')
subprocess.run([
    "npm", "exec", "--yes", "--package=@resvg/resvg-js-cli@2.6.2-beta.1", "--",
    "resvg-js", "--no-system-font", "--fit-width", "452", "-",
    "client/module_prego/assets/images/brands/antigravity.png",
], input=source, text=True, check=True)
```

## Grok Build

The Grok marks are used only to identify Grok Build. Their canonical sources are
xAI's [brand guidelines](https://x.ai/legal/brand-guidelines) and official
[`xAI_Grok_Assets.zip`](https://data.x.ai/logos/xAI_Grok_Assets.zip) package.
The direct package is Cloudflare-protected, so the checked bytes were retrieved
from the Wayback Machine's archived official response at capture
`20250910134422`. The archive SHA-256 is
`f41a93923a85047b4b5a9571b7ec73339f562c3e58acd096e25584ab0ae2a1fb`.

- `assets/svgs/brands/grok_light.svg` is the exact upstream
  `Grok_Logomark_Dark.svg`. SHA-256:
  `a127a7cd42b0450f7d3827a331b0730aab49fd99c3fe920d172475b9ffc83992`.
- `assets/svgs/brands/grok_dark.svg` is the exact upstream
  `Grok_Logomark_Light.svg`. SHA-256:
  `b20648e2f111d7fbc91f58b22d1e76e9885b68a163cb5a1010f7f11bf5840491`.

Both files are bundled byte-for-byte without recolouring, optimization, or
metadata changes. They contain no scripts, external references, or metadata;
the XML namespace URI is declarative and does not fetch remote content.

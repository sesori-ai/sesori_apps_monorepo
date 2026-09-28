const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

const filePreviews = {
  agents: {
    title: "AGENTS.md",
    path: "/AGENTS.md · Markdown",
    content: `# Sesori Agent Context

## Project and stakes
Sesori lets developers monitor and control AI coding sessions from phone and desktop surfaces.

## Working rules
- Prefer the smallest change that fully solves the demonstrated problem.
- Preserve source-code privacy and persisted session integrity.
- Verify behavior at the actual product boundary.`,
  },
  "index-astro": {
    title: "index.astro",
    path: "/website/src/pages/index.astro · Astro",
    content: `---
import Layout from "../layouts/Layout.astro";
import ChatStateDemo from "../components/ChatStateDemo.astro";
---

<Layout title="AI chat states">
  <ChatStateDemo />
</Layout>`,
  },
  "tool-call": {
    title: "tool-call.txt",
    path: "/website/tool-call.txt · Plain text",
    content: `Created while prototyping the selected card background.

Files checked:
- src/components/FeatureCard.astro
- src/styles/product-features.css

Status: ready for review`,
  },
};

const filePreviewSheet = document.getElementById("file-preview-sheet");
const filePreviewTitle = document.getElementById("file-preview-title");
const filePreviewPath = document.getElementById("file-preview-path");
const filePreviewContent = document.getElementById("file-preview-content");
let lastFilePreviewTrigger = null;
let filePreviewCloseTimer = null;

function finishClosingFilePreview() {
  window.clearTimeout(filePreviewCloseTimer);
  filePreviewCloseTimer = null;
  filePreviewSheet.removeAttribute("data-entering");
  filePreviewSheet.removeAttribute("data-closing");
  if (filePreviewSheet.open) filePreviewSheet.close();
}

function closeFilePreview() {
  if (!filePreviewSheet.open || filePreviewSheet.hasAttribute("data-closing")) return;

  filePreviewSheet.setAttribute("data-closing", "");
  const closeDuration = prefersReducedMotion.matches ? 130 : 210;
  filePreviewCloseTimer = window.setTimeout(finishClosingFilePreview, closeDuration);
}

function openFilePreview(trigger) {
  const preview = filePreviews[trigger.dataset.filePreview];
  if (!preview) return;

  lastFilePreviewTrigger = trigger;
  filePreviewTitle.textContent = preview.title;
  filePreviewPath.textContent = preview.path;
  filePreviewContent.textContent = preview.content;
  filePreviewSheet.setAttribute("data-entering", "");
  filePreviewSheet.showModal();

  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => filePreviewSheet.removeAttribute("data-entering"));
  });
}

document.querySelectorAll("[data-file-preview]").forEach((trigger) => {
  trigger.addEventListener("click", () => openFilePreview(trigger));
});

document.querySelector("[data-file-preview-close]").addEventListener("click", closeFilePreview);

filePreviewSheet.addEventListener("cancel", (event) => {
  event.preventDefault();
  closeFilePreview();
});

filePreviewSheet.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    event.preventDefault();
    closeFilePreview();
    return;
  }

  if (event.key !== "Tab") return;

  const focusable = [
    ...filePreviewSheet.querySelectorAll(
      'button:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])',
    ),
  ];
  if (focusable.length === 0) return;

  const currentIndex = focusable.indexOf(document.activeElement);
  const nextIndex = event.shiftKey
    ? (currentIndex - 1 + focusable.length) % focusable.length
    : (currentIndex + 1) % focusable.length;
  event.preventDefault();
  focusable[nextIndex].focus();
});

filePreviewSheet.addEventListener("click", (event) => {
  if (event.target === filePreviewSheet) closeFilePreview();
});

filePreviewSheet.addEventListener("close", () => {
  const trigger = lastFilePreviewTrigger;
  lastFilePreviewTrigger = null;
  trigger?.focus();
});

function syncShimmerDistance(shimmer) {
  const base = shimmer.querySelector(".shimmer-base");
  const shimmerWindow = shimmer.querySelector(".shimmer-window");
  const copy = shimmer.querySelector(".shimmer-copy");
  if (!base || !shimmerWindow || !copy) return;

  const run = Math.ceil(base.getBoundingClientRect().width + 30);
  shimmerWindow.style.setProperty("--shimmer-run", `${run}px`);
  copy.style.setProperty("--shimmer-return", `${-run}px`);
}

const shimmerLabels = [...document.querySelectorAll("[data-shimmer]")];
const syncShimmers = () => shimmerLabels.forEach(syncShimmerDistance);

const elapsedTimers = [...document.querySelectorAll("[data-elapsed-timer]")].map((timer) => ({
  element: timer,
  startedAt:
    Date.now() - Number.parseInt(timer.dataset.startSeconds ?? "0", 10) * 1000,
}));

function updateElapsedTimers() {
  const now = Date.now();

  elapsedTimers.forEach(({ element, startedAt }) => {
    const elapsedSeconds = Math.max(0, Math.floor((now - startedAt) / 1000));
    const minutes = Math.floor(elapsedSeconds / 60);
    const seconds = elapsedSeconds % 60;
    const label = `Working for ${minutes}min ${seconds}s`;

    element.querySelectorAll(".shimmer-base, .shimmer-copy").forEach((copy) => {
      copy.textContent = label;
    });
    syncShimmerDistance(element);
  });
}

function scheduleElapsedTimerUpdate() {
  updateElapsedTimers();
  const firstTimer = elapsedTimers[0];
  if (!firstTimer) return;

  const elapsedMilliseconds = Date.now() - firstTimer.startedAt;
  const delayUntilNextSecond = 1010 - (elapsedMilliseconds % 1000);
  window.setTimeout(scheduleElapsedTimerUpdate, delayUntilNextSecond);
}

syncShimmers();
scheduleElapsedTimerUpdate();
document.fonts?.ready.then(syncShimmers);

if ("ResizeObserver" in window) {
  const shimmerObserver = new ResizeObserver(syncShimmers);
  shimmerLabels.forEach((shimmer) => shimmerObserver.observe(shimmer));
}

function revealExpandedPanel(toggle, panel) {
  const scrollViewport = toggle.closest("[data-scroll-viewport]");
  if (!scrollViewport) return;

  const viewportRect = scrollViewport.getBoundingClientRect();
  const toggleRect = toggle.getBoundingClientRect();
  const panelRect = panel.getBoundingClientRect();
  const fadeInset =
    Number.parseFloat(getComputedStyle(scrollViewport).getPropertyValue("--scroll-fade-size")) || 48;
  const safeTop = viewportRect.top + fadeInset;
  const safeBottom = viewportRect.bottom - fadeInset;
  const safeHeight = safeBottom - safeTop;
  const disclosureHeight = panelRect.bottom - toggleRect.top;
  let scrollDelta = 0;

  if (disclosureHeight > safeHeight) {
    scrollDelta = toggleRect.top - safeTop;
  } else if (panelRect.bottom > safeBottom) {
    scrollDelta = panelRect.bottom - safeBottom;
  } else if (toggleRect.top < safeTop) {
    scrollDelta = toggleRect.top - safeTop;
  }

  if (Math.abs(scrollDelta) < 1) return;

  scrollViewport.scrollBy({
    top: scrollDelta,
    behavior: prefersReducedMotion.matches ? "auto" : "smooth",
  });
}

const accordionEasing = "cubic-bezier(0.23, 1, 0.32, 1)";
const panelMotions = new WeakMap();

function collectFollowingLayoutItems(panel, scrollViewport) {
  const items = [];
  const seen = new Set();
  let node = panel;

  while (node && node !== scrollViewport) {
    let sibling = node.nextElementSibling;
    while (sibling) {
      if (!seen.has(sibling)) {
        seen.add(sibling);
        items.push(sibling);
      }
      sibling = sibling.nextElementSibling;
    }
    node = node.parentElement;
  }

  return items;
}

function measureLayoutItems(items) {
  return new Map(
    items.map((item) => {
      const rect = item.getBoundingClientRect();
      return [item, rect.width > 0 && rect.height > 0 ? rect : null];
    }),
  );
}

function animateLayoutItems(items, beforeRects, duration) {
  const animations = [];

  items.forEach((item) => {
    const before = beforeRects.get(item);
    const after = item.getBoundingClientRect();
    if (!before || after.width === 0 || after.height === 0) return;

    const deltaX = before.left - after.left;
    const deltaY = before.top - after.top;
    if (Math.abs(deltaX) < 0.5 && Math.abs(deltaY) < 0.5) return;

    animations.push(
      item.animate(
        [
          { transform: `translate3d(${deltaX}px, ${deltaY}px, 0)` },
          { transform: "translate3d(0, 0, 0)" },
        ],
        { duration, easing: accordionEasing, fill: "both" },
      ),
    );
  });

  return animations;
}

function findOpaqueSurface(element) {
  let node = element;

  while (node) {
    const color = getComputedStyle(node).backgroundColor;
    if (color !== "transparent" && color !== "rgba(0, 0, 0, 0)") return color;
    node = node.parentElement;
  }

  return "rgb(20, 20, 20)";
}

function layerPanelAboveMovingContent(panel) {
  const panelBackground = getComputedStyle(panel).backgroundColor;
  panel.style.position = "relative";
  panel.style.zIndex = "2";

  if (panelBackground === "transparent" || panelBackground === "rgba(0, 0, 0, 0)") {
    panel.style.backgroundColor = findOpaqueSurface(panel.parentElement);
  }
}

function stopPanelMotion(panel) {
  const motion = panelMotions.get(panel);
  if (!motion) return;

  motion.animations.forEach((animation) => animation.cancel());
  motion.restore?.();
  panelMotions.delete(panel);
}

function finishPanelMotion(panel, expanding, toggle, motion) {
  if (panelMotions.get(panel) !== motion) return;

  motion.animations.forEach((animation) => animation.cancel());
  motion.restore?.();
  panel.hidden = !expanding;
  panelMotions.delete(panel);

  if (expanding) {
    window.requestAnimationFrame(() => revealExpandedPanel(toggle, panel));
  }
}

function animateReducedMotionPanel(panel, expanding, toggle) {
  if (expanding) panel.hidden = false;

  const animation = panel.animate(
    [{ opacity: expanding ? 0 : 1 }, { opacity: expanding ? 1 : 0 }],
    { duration: 120, easing: accordionEasing, fill: "both" },
  );
  const motion = { animations: [animation], restore: null };
  panelMotions.set(panel, motion);
  animation.addEventListener(
    "finish",
    () => finishPanelMotion(panel, expanding, toggle, motion),
    { once: true },
  );
}

function animatePanel(panel, expanding, toggle) {
  const scrollViewport = toggle.closest("[data-scroll-viewport]");
  const layoutItems = scrollViewport
    ? collectFollowingLayoutItems(panel, scrollViewport)
    : [];
  const beforeRects = measureLayoutItems(layoutItems);
  const wasHidden = panel.hidden;
  const visualRect = wasHidden ? null : panel.getBoundingClientRect();
  const visualOpacity = wasHidden ? 0 : Number.parseFloat(getComputedStyle(panel).opacity);

  stopPanelMotion(panel);

  if (prefersReducedMotion.matches) {
    animateReducedMotionPanel(panel, expanding, toggle);
    return;
  }

  const duration = expanding ? 200 : 150;
  const animations = [];
  let restore = null;

  if (expanding) {
    panel.hidden = false;
    layerPanelAboveMovingContent(panel);
    restore = () => {
      ["position", "z-index", "background-color"].forEach((property) =>
        panel.style.removeProperty(property),
      );
    };
    const finalRect = panel.getBoundingClientRect();
    const startY = visualRect ? visualRect.top - finalRect.top : -4;
    const panelAnimation = panel.animate(
      [
        {
          filter: "blur(2px)",
          opacity: visualOpacity,
          transform: `translate3d(0, ${startY}px, 0)`,
        },
        { filter: "blur(0)", opacity: 1, transform: "translate3d(0, 0, 0)" },
      ],
      { duration, easing: accordionEasing, fill: "both" },
    );
    animations.push(
      panelAnimation,
      ...animateLayoutItems(layoutItems, beforeRects, duration),
    );

    const motion = { animations, restore };
    panelMotions.set(panel, motion);
    panelAnimation.addEventListener(
      "finish",
      () => finishPanelMotion(panel, true, toggle, motion),
      { once: true },
    );
    return;
  }

  if (!visualRect) {
    panel.hidden = true;
    return;
  }

  panel.style.position = "fixed";
  panel.style.inset = "auto";
  panel.style.top = `${visualRect.top}px`;
  panel.style.left = `${visualRect.left}px`;
  panel.style.width = `${visualRect.width}px`;
  panel.style.height = `${visualRect.height}px`;
  panel.style.margin = "0";
  panel.style.zIndex = "2";
  panel.style.pointerEvents = "none";
  panel.style.opacity = String(visualOpacity);
  panel.style.transform = "none";
  const panelBackground = getComputedStyle(panel).backgroundColor;
  if (panelBackground === "transparent" || panelBackground === "rgba(0, 0, 0, 0)") {
    panel.style.backgroundColor = findOpaqueSurface(panel.parentElement);
  }
  restore = () => {
    [
      "position",
      "inset",
      "top",
      "left",
      "width",
      "height",
      "margin",
      "z-index",
      "pointer-events",
      "opacity",
      "transform",
      "background-color",
    ].forEach((property) => panel.style.removeProperty(property));
  };

  const panelAnimation = panel.animate(
    [
      { filter: "blur(0)", opacity: visualOpacity, transform: "translate3d(0, 0, 0)" },
      { filter: "blur(2px)", opacity: 0, transform: "translate3d(0, -4px, 0)" },
    ],
    { duration, easing: accordionEasing, fill: "both" },
  );
  animations.push(
    panelAnimation,
    ...animateLayoutItems(layoutItems, beforeRects, duration),
  );

  const motion = { animations, restore };
  panelMotions.set(panel, motion);
  panelAnimation.addEventListener(
    "finish",
    () => finishPanelMotion(panel, false, toggle, motion),
    { once: true },
  );
}

document.querySelectorAll("[data-accordion-toggle]").forEach((toggle) => {
  toggle.addEventListener("click", () => {
    const panelId = toggle.getAttribute("aria-controls");
    const panel = document.getElementById(panelId);
    if (!panel) return;

    const expanding = toggle.getAttribute("aria-expanded") !== "true";
    toggle.setAttribute("aria-expanded", String(expanding));

    animatePanel(panel, expanding, toggle);
  });
});

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const value = button.dataset.copy;
    if (!value) return;

    try {
      await navigator.clipboard.writeText(value);
      button.dataset.copied = "true";
      const originalLabel = button.getAttribute("aria-label") ?? "Copy";
      button.setAttribute("aria-label", "Copied");

      window.setTimeout(() => {
        button.removeAttribute("data-copied");
        button.setAttribute("aria-label", originalLabel);
      }, 1200);
    } catch (error) {
      console.warn("Clipboard copy failed in the local demo.", error);
    }
  });
});

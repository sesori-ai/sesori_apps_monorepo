const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

function animatePanel(panel, expanding) {
  const runningAnimations = panel.getAnimations();
  const currentHeight = panel.hidden ? 0 : panel.getBoundingClientRect().height;

  runningAnimations.forEach((animation) => {
    if (animation.playState === "running") {
      try {
        animation.commitStyles();
      } catch (error) {
        console.warn("Could not preserve the interrupted accordion frame.", error);
      }
    }
    animation.cancel();
  });

  if (prefersReducedMotion.matches) {
    if (expanding) panel.hidden = false;

    const reducedMotionAnimation = panel.animate(
      [{ opacity: expanding ? 0 : 1 }, { opacity: expanding ? 1 : 0 }],
      { duration: 120, easing: "cubic-bezier(0.23, 1, 0.32, 1)", fill: "both" },
    );

    reducedMotionAnimation.addEventListener("finish", () => {
      panel.hidden = !expanding;
      panel.style.removeProperty("height");
      panel.style.removeProperty("opacity");
      panel.style.removeProperty("overflow");
    });
    return;
  }

  if (expanding) {
    panel.hidden = false;
  }

  const startHeight = currentHeight;
  const endHeight = expanding ? panel.scrollHeight : 0;
  const animation = panel.animate(
    [
      { height: `${startHeight}px`, opacity: expanding ? 0 : 1, overflow: "hidden" },
      { height: `${endHeight}px`, opacity: expanding ? 1 : 0, overflow: "hidden" },
    ],
    {
      duration: 200,
      easing: "cubic-bezier(0.23, 1, 0.32, 1)",
      fill: "both",
    },
  );

  animation.addEventListener("finish", () => {
    panel.hidden = !expanding;
    panel.style.removeProperty("height");
    panel.style.removeProperty("opacity");
    panel.style.removeProperty("overflow");
  });
}

document.querySelectorAll("[data-accordion-toggle]").forEach((toggle) => {
  toggle.addEventListener("click", () => {
    const panelId = toggle.getAttribute("aria-controls");
    const panel = document.getElementById(panelId);
    if (!panel) return;

    const expanding = toggle.getAttribute("aria-expanded") !== "true";
    toggle.setAttribute("aria-expanded", String(expanding));

    const chevron = toggle.querySelector(".chevron");
    if (chevron) {
      chevron.textContent = expanding ? "\uEA5F" : "\uEA61";
    }

    animatePanel(panel, expanding);
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

document.querySelectorAll(".remove-image").forEach((button) => {
  button.addEventListener("click", () => {
    const preview = button.closest(".image-preview");
    if (preview) preview.hidden = true;
  });
});

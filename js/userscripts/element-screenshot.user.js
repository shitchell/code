// ==UserScript==
// @name         Element Screenshot
// @namespace    https://github.com/guy
// @version      1.1
// @description  Take element-based screenshots with a visual picker
// @author       You
// @match        *://*/*
// @grant        GM_registerMenuCommand
// @grant        GM_getValue
// @grant        GM_setValue
// @require      https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js
// ==/UserScript==

(function () {
  "use strict";

  // ============== CONFIGURATION ==============
  const DEFAULT_HOTKEY = {
    key: "s",
    ctrl: true,
    alt: true,
    shift: false,
  };

  // Output modes: "download", "clipboard", "both"
  const DEFAULT_OUTPUT = "download";

  // Load/save settings
  const getHotkey = () => GM_getValue("hotkey", DEFAULT_HOTKEY);
  const setHotkey = (hotkey) => GM_setValue("hotkey", hotkey);
  const getOutputMode = () => GM_getValue("outputMode", DEFAULT_OUTPUT);
  const setOutputMode = (mode) => GM_setValue("outputMode", mode);

  // ============== STATE ==============
  let isActive = false;
  let overlay = null;
  let highlightBox = null;
  let crosshairV = null;
  let crosshairH = null;
  let currentElement = null;
  let innermostElement = null; // The deepest element under cursor
  let elementAncestors = [];   // Chain from innermost to body
  let ancestorIndex = 0;       // Current position in ancestor chain
  // html2canvas is loaded via @require

  // ============== UI CREATION ==============
  const createOverlay = () => {
    // Main dimming overlay
    overlay = document.createElement("div");
    overlay.id = "es-overlay";
    overlay.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(0, 0, 0, 0.5);
      z-index: 2147483640;
      cursor: crosshair;
      pointer-events: auto;
    `;

    // Highlight box
    highlightBox = document.createElement("div");
    highlightBox.id = "es-highlight";
    highlightBox.style.cssText = `
      position: fixed;
      border: 2px solid #00ffff;
      background: rgba(0, 255, 255, 0.1);
      z-index: 2147483641;
      pointer-events: none;
      box-shadow: 0 0 10px rgba(0, 255, 255, 0.5);
      transition: all 0.05s ease-out;
    `;

    // Crosshair vertical line
    crosshairV = document.createElement("div");
    crosshairV.id = "es-crosshair-v";
    crosshairV.style.cssText = `
      position: fixed;
      width: 1px;
      height: 100vh;
      background: rgba(255, 255, 255, 0.6);
      z-index: 2147483642;
      pointer-events: none;
      top: 0;
    `;

    // Crosshair horizontal line
    crosshairH = document.createElement("div");
    crosshairH.id = "es-crosshair-h";
    crosshairH.style.cssText = `
      position: fixed;
      width: 100vw;
      height: 1px;
      background: rgba(255, 255, 255, 0.6);
      z-index: 2147483642;
      pointer-events: none;
      left: 0;
    `;

    // Instructions tooltip
    const tooltip = document.createElement("div");
    tooltip.id = "es-tooltip";
    tooltip.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(0, 0, 0, 0.8);
      color: white;
      padding: 10px 20px;
      border-radius: 8px;
      font-family: system-ui, sans-serif;
      font-size: 14px;
      z-index: 2147483643;
      pointer-events: none;
    `;
    tooltip.textContent = "Click to capture • Scroll to select parent/child • ESC to cancel";

    document.body.appendChild(overlay);
    document.body.appendChild(highlightBox);
    document.body.appendChild(crosshairV);
    document.body.appendChild(crosshairH);
    document.body.appendChild(tooltip);
  };

  const removeOverlay = () => {
    ["es-overlay", "es-highlight", "es-crosshair-v", "es-crosshair-h", "es-tooltip"]
      .forEach((id) => document.getElementById(id)?.remove());
    overlay = null;
    highlightBox = null;
    crosshairV = null;
    crosshairH = null;
    currentElement = null;
  };

  // ============== HELPER FUNCTIONS ==============
  const getAncestors = (element) => {
    const ancestors = [];
    let el = element;
    while (el && el !== document.body && el !== document.documentElement) {
      ancestors.push(el);
      el = el.parentElement;
    }
    if (document.body) ancestors.push(document.body);
    return ancestors;
  };

  const updateHighlight = () => {
    if (!currentElement) return;
    const rect = currentElement.getBoundingClientRect();
    highlightBox.style.left = rect.left + "px";
    highlightBox.style.top = rect.top + "px";
    highlightBox.style.width = rect.width + "px";
    highlightBox.style.height = rect.height + "px";
    highlightBox.style.display = "block";
  };

  // ============== EVENT HANDLERS ==============
  const handleMouseMove = (e) => {
    // Update crosshairs
    crosshairV.style.left = e.clientX + "px";
    crosshairH.style.top = e.clientY + "px";

    // Find element under cursor (temporarily hide overlay)
    overlay.style.pointerEvents = "none";
    const element = document.elementFromPoint(e.clientX, e.clientY);
    overlay.style.pointerEvents = "auto";

    if (element && !element.id?.startsWith("es-")) {
      // Only rebuild ancestor chain if we moved to a different innermost element
      if (element !== innermostElement) {
        innermostElement = element;
        elementAncestors = getAncestors(element);
        ancestorIndex = 0;
      }
      currentElement = elementAncestors[ancestorIndex];
      updateHighlight();
    }
  };

  const handleScroll = (e) => {
    e.preventDefault();
    e.stopPropagation();

    if (elementAncestors.length === 0) return;

    if (e.deltaY > 0) {
      // Scroll down - go to child (more specific)
      ancestorIndex = Math.max(0, ancestorIndex - 1);
    } else {
      // Scroll up - go to parent (less specific)
      ancestorIndex = Math.min(elementAncestors.length - 1, ancestorIndex + 1);
    }

    currentElement = elementAncestors[ancestorIndex];
    updateHighlight();
  };

  const handleClick = async (e) => {
    e.preventDefault();
    e.stopPropagation();

    if (!currentElement) return;

    const elementToCapture = currentElement;
    deactivate();

    try {
      const canvas = await html2canvas(elementToCapture, {
        useCORS: true,
        allowTaint: true,
        backgroundColor: null,
        logging: false,
      });

      const outputMode = getOutputMode();

      canvas.toBlob(async (blob) => {
        // Copy to clipboard
        if (outputMode === "clipboard" || outputMode === "both") {
          try {
            await navigator.clipboard.write([
              new ClipboardItem({ "image/png": blob }),
            ]);
          } catch (clipErr) {
            console.error("Clipboard copy failed:", clipErr);
            alert("Clipboard copy failed: " + clipErr.message);
          }
        }

        // Download file
        if (outputMode === "download" || outputMode === "both") {
          const url = URL.createObjectURL(blob);
          const a = document.createElement("a");
          a.href = url;
          a.download = `screenshot-${Date.now()}.png`;
          a.click();
          URL.revokeObjectURL(url);
        }
      }, "image/png");
    } catch (err) {
      console.error("Screenshot failed:", err);
      alert("Screenshot failed: " + err.message);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === "Escape") {
      deactivate();
    }
  };

  // ============== ACTIVATION ==============
  const activate = () => {
    if (isActive) return;
    isActive = true;
    createOverlay();
    document.addEventListener("mousemove", handleMouseMove, true);
    overlay.addEventListener("click", handleClick, true);
    overlay.addEventListener("wheel", handleScroll, { passive: false, capture: true });
    document.addEventListener("keydown", handleKeyDown, true);
  };

  const deactivate = () => {
    if (!isActive) return;
    isActive = false;
    document.removeEventListener("mousemove", handleMouseMove, true);
    document.removeEventListener("keydown", handleKeyDown, true);
    innermostElement = null;
    elementAncestors = [];
    ancestorIndex = 0;
    removeOverlay();
  };

  // ============== HOTKEY DETECTION ==============
  const matchesHotkey = (e, hotkey) => {
    return (
      e.key.toLowerCase() === hotkey.key.toLowerCase() &&
      e.ctrlKey === hotkey.ctrl &&
      e.altKey === hotkey.alt &&
      e.shiftKey === hotkey.shift
    );
  };

  document.addEventListener("keydown", (e) => {
    if (matchesHotkey(e, getHotkey())) {
      e.preventDefault();
      if (isActive) {
        deactivate();
      } else {
        activate();
      }
    }
  });

  // ============== CONFIGURATION MENU ==============
  const formatHotkey = (hotkey) => {
    const parts = [];
    if (hotkey.ctrl) parts.push("Ctrl");
    if (hotkey.alt) parts.push("Alt");
    if (hotkey.shift) parts.push("Shift");
    parts.push(hotkey.key.toUpperCase());
    return parts.join("+");
  };

  GM_registerMenuCommand(`Change Hotkey (${formatHotkey(getHotkey())})`, () => {
    const current = getHotkey();
    const input = prompt(
      `Enter new hotkey (format: ctrl+alt+shift+key)\nCurrent: ${formatHotkey(current)}`,
      formatHotkey(current)
    );

    if (!input) return;

    const parts = input.toLowerCase().split("+").map((s) => s.trim());
    const newHotkey = {
      key: parts[parts.length - 1],
      ctrl: parts.includes("ctrl"),
      alt: parts.includes("alt"),
      shift: parts.includes("shift"),
    };

    setHotkey(newHotkey);
    alert(`Hotkey changed to: ${formatHotkey(newHotkey)}`);
  });

  const outputLabels = {
    download: "Download",
    clipboard: "Clipboard",
    both: "Both",
  };

  GM_registerMenuCommand(`Output Mode (${outputLabels[getOutputMode()]})`, () => {
    const modes = ["download", "clipboard", "both"];
    const current = getOutputMode();
    const next = modes[(modes.indexOf(current) + 1) % modes.length];
    setOutputMode(next);
    alert(`Output mode changed to: ${outputLabels[next]}`);
  });

  GM_registerMenuCommand("Take Element Screenshot", activate);
})();

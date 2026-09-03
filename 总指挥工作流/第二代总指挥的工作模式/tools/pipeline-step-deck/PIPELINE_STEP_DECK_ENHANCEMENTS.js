(function () {
  "use strict";

  const VERSION = "1.0.0";
  const CONTROL_ATTRIBUTE = "data-deck-control";
  const STYLE_ID = "pipeline-step-deck-enhancement-style";

  const STYLE = `
    .deck-column-heading,
    .deck-card-heading {
      display: flex;
      align-items: flex-start;
      gap: 8px;
    }

    .deck-column-title,
    .deck-card-title {
      flex: 1 1 auto;
      min-width: 0;
    }

    .deck-utility-button {
      flex: 0 0 auto;
      min-width: 44px;
      min-height: 22px;
      padding: 2px 7px;
      border: 1px solid #9dbfba;
      border-radius: 7px;
      background: #fff;
      color: #086a61;
      font: 700 11px/1.25 system-ui, sans-serif;
      cursor: pointer;
    }

    .deck-utility-button:hover { background: #e8f6f3; }
    .deck-utility-button:disabled { cursor: wait; opacity: .72; }
    .deck-utility-button:focus-visible { outline: 2px solid #0a8c7e; outline-offset: 2px; }
    .deck-export-button { min-width: 66px; white-space: nowrap; }

    .deck-copyable-output {
      position: relative;
      width: 100%;
      min-height: 0;
    }

    .deck-copyable-output > .deck-copy-button {
      position: absolute;
      top: 7px;
      right: 7px;
      z-index: 2;
      border-color: rgba(255,255,255,.5);
      background: rgba(21,33,39,.88);
      color: #fff;
    }

    .deck-copyable-output > .deck-copy-button:hover { background: #23363e; }
  `;

  function installStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = STYLE;
    document.head.appendChild(style);
  }

  function makeButton(label, title, className) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = ("deck-utility-button " + (className || "")).trim();
    button.textContent = label;
    button.title = title;
    button.setAttribute(CONTROL_ATTRIBUTE, "true");
    return button;
  }

  async function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      try {
        await navigator.clipboard.writeText(text);
        return;
      } catch {
        // 浏览器拒绝 Clipboard API 时继续尝试兼容路径。
      }
    }
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.left = "-100000px";
    document.body.appendChild(textarea);
    textarea.select();
    const copied = document.execCommand("copy");
    textarea.remove();
    if (!copied) throw new Error("浏览器拒绝了剪贴板写入");
  }

  function textFromNode(node) {
    if (node.matches("table")) {
      return Array.from(node.rows).map((row) =>
        Array.from(row.cells).map((cell) => String(cell.textContent || "").trim()).join("\t")
      ).join("\n");
    }
    return String(node.textContent || "");
  }

  function makeCopyButton(textProvider) {
    const button = makeButton("复制", "一键复制完整文本", "deck-copy-button");
    button.addEventListener("click", async () => {
      const original = "复制";
      button.disabled = true;
      try {
        const text = String(textProvider() || "");
        await copyText(text);
        button.textContent = "已复制";
        button.dataset.state = "success";
        button.dataset.lastCopyLength = String(text.length);
      } catch (error) {
        console.error("复制失败", error);
        button.textContent = "复制失败";
        button.dataset.state = "error";
      } finally {
        window.setTimeout(() => {
          button.textContent = original;
          button.disabled = false;
          delete button.dataset.state;
        }, 1600);
      }
    });
    return button;
  }

  function wrapHeadingText(heading, className) {
    const existing = heading.querySelector(":scope > ." + className);
    if (existing) return existing;
    const span = document.createElement("span");
    span.className = className;
    Array.from(heading.childNodes).forEach((node) => {
      if (!(node.nodeType === Node.ELEMENT_NODE && node.hasAttribute && node.hasAttribute(CONTROL_ATTRIBUTE))) {
        span.appendChild(node);
      }
    });
    heading.prepend(span);
    return span;
  }

  function enhanceCopyNode(node) {
    if (node.dataset.deckCopyEnhanced === VERSION) return;
    node.dataset.deckCopyEnhanced = VERSION;
    const card = node.closest(".comparison-card");
    const button = makeCopyButton(() => textFromNode(node));
    if (card) {
      const heading = card.querySelector(":scope > h4");
      if (!heading) return;
      heading.classList.add("deck-card-heading");
      wrapHeadingText(heading, "deck-card-title");
      heading.appendChild(button);
      return;
    }
    const wrapper = document.createElement("div");
    wrapper.className = "deck-copyable-output";
    node.before(wrapper);
    wrapper.append(node, button);
  }

  function safeFileName(value) {
    return String(value || "阶段输出")
      .replace(/[<>:"/\\|?*\u0000-\u001f]/g, "-")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 96) || "阶段输出";
  }

  function canvasToPngBlob(canvas) {
    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) resolve(blob);
        else reject(new Error("长图编码失败"));
      }, "image/png");
    });
  }

  function drawRoundedRect(context, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    context.beginPath();
    context.moveTo(x + r, y);
    context.lineTo(x + width - r, y);
    context.quadraticCurveTo(x + width, y, x + width, y + r);
    context.lineTo(x + width, y + height - r);
    context.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    context.lineTo(x + r, y + height);
    context.quadraticCurveTo(x, y + height, x, y + height - r);
    context.lineTo(x, y + r);
    context.quadraticCurveTo(x, y, x + r, y);
    context.closePath();
  }

  function wrapText(context, value, maximumWidth, maximumLines) {
    const lines = [];
    const limit = Number.isFinite(maximumLines) ? maximumLines : Infinity;
    const paragraphs = String(value || "").replace(/\r/g, "").split("\n");
    let truncated = false;
    for (const paragraph of paragraphs) {
      if (lines.length >= limit) {
        truncated = true;
        break;
      }
      if (!paragraph) {
        lines.push("");
        continue;
      }
      let line = "";
      for (const character of paragraph) {
        const candidate = line + character;
        if (line && context.measureText(candidate).width > maximumWidth) {
          lines.push(line);
          line = character;
          if (lines.length >= limit) {
            truncated = true;
            break;
          }
        } else {
          line = candidate;
        }
      }
      if (lines.length >= limit) break;
      if (line) lines.push(line);
    }
    if (truncated && lines.length) lines[lines.length - 1] += "…";
    return { lines, truncated };
  }

  function textWithoutControls(element) {
    if (!element) return "";
    const clone = element.cloneNode(true);
    clone.querySelectorAll("[" + CONTROL_ATTRIBUTE + "]").forEach((control) => control.remove());
    return String(clone.textContent || "").trim();
  }

  function waitForImage(image) {
    image.loading = "eager";
    if (image.complete) {
      return image.naturalWidth > 0
        ? Promise.resolve(image)
        : Promise.reject(new Error("页面图片没有可导出的像素"));
    }
    return new Promise((resolve, reject) => {
      image.addEventListener("load", () => resolve(image), { once: true });
      image.addEventListener("error", () => reject(new Error("页面图片加载失败")), { once: true });
    });
  }

  async function collectCards(column) {
    const cards = Array.from(column.querySelectorAll(".comparison-card"));
    if (!cards.length) {
      const placeholder = column.querySelector(".comparison-items > .placeholder");
      return [{
        title: "本次路径未执行该节点",
        caption: "",
        kind: "placeholder",
        text: textWithoutControls(placeholder)
      }];
    }
    return Promise.all(cards.map(async (card) => {
      const output = card.querySelector(".comparison-card-output");
      const image = output && output.querySelector("img");
      const code = output && output.querySelector("pre.evidence-code");
      const table = output && output.querySelector("table");
      const placeholder = output && output.querySelector(".placeholder");
      const model = {
        title: textWithoutControls(card.querySelector(":scope > h4")),
        caption: String((card.querySelector(":scope > .comparison-item-caption") || {}).textContent || "").trim(),
        kind: "text",
        text: ""
      };
      if (image) {
        try {
          model.kind = "image";
          model.image = await waitForImage(image);
        } catch (error) {
          model.kind = "placeholder";
          model.text = error.message;
        }
      } else if (code) {
        model.kind = "code";
        model.text = String(code.textContent || "");
      } else if (table) {
        model.kind = "table";
        model.text = textFromNode(table);
      } else if (placeholder) {
        model.kind = "placeholder";
        model.text = textWithoutControls(placeholder);
      } else {
        model.text = textWithoutControls(output);
      }
      return model;
    }));
  }

  function makeCardLayout(context, model, cardWidth) {
    const innerWidth = cardWidth - 24;
    context.font = '700 14px "Segoe UI","Microsoft YaHei",sans-serif';
    const title = wrapText(context, model.title, innerWidth, 4);
    const titleHeight = Math.max(40, 16 + title.lines.length * 20);
    let bodyHeight = 0;
    let bodyLines = [];
    let bodyTruncated = false;
    if (model.kind === "image") {
      const ratioHeight = innerWidth * model.image.naturalHeight / model.image.naturalWidth;
      bodyHeight = Math.max(100, Math.min(260, ratioHeight));
    } else {
      context.font = model.kind === "code" || model.kind === "table"
        ? '12px Consolas,"Microsoft YaHei",monospace'
        : '13px "Segoe UI","Microsoft YaHei",sans-serif';
      const wrapped = wrapText(context, model.text, innerWidth - 20, model.kind === "placeholder" ? 8 : 18);
      bodyLines = wrapped.lines;
      bodyTruncated = wrapped.truncated;
      bodyHeight = Math.max(76, 22 + bodyLines.length * 18 + (bodyTruncated ? 26 : 0));
    }
    context.font = '12px "Segoe UI","Microsoft YaHei",sans-serif';
    const caption = model.caption ? wrapText(context, model.caption, innerWidth, 6) : { lines: [] };
    const captionHeight = caption.lines.length ? 12 + caption.lines.length * 18 : 0;
    return {
      model,
      titleLines: title.lines,
      titleHeight,
      bodyLines,
      bodyTruncated,
      bodyHeight,
      captionLines: caption.lines,
      captionHeight,
      height: titleHeight + bodyHeight + captionHeight
    };
  }

  function drawCard(context, layout, x, y, width) {
    drawRoundedRect(context, x, y, width, layout.height, 10);
    context.fillStyle = "#fff";
    context.fill();
    context.strokeStyle = "#c9d6da";
    context.lineWidth = 1;
    context.stroke();
    context.fillStyle = "#15242b";
    context.font = '700 14px "Segoe UI","Microsoft YaHei",sans-serif';
    layout.titleLines.forEach((line, index) => context.fillText(line, x + 12, y + 18 + index * 20));
    const bodyY = y + layout.titleHeight;
    context.strokeStyle = "#c9d6da";
    context.beginPath();
    context.moveTo(x, bodyY + .5);
    context.lineTo(x + width, bodyY + .5);
    context.stroke();
    if (layout.model.kind === "image") {
      context.fillStyle = "#f2f6f6";
      context.fillRect(x + 1, bodyY + 1, width - 2, layout.bodyHeight - 1);
      const availableWidth = width - 24;
      const scale = Math.min(
        availableWidth / layout.model.image.naturalWidth,
        layout.bodyHeight / layout.model.image.naturalHeight
      );
      const drawWidth = layout.model.image.naturalWidth * scale;
      const drawHeight = layout.model.image.naturalHeight * scale;
      context.drawImage(
        layout.model.image,
        x + (width - drawWidth) / 2,
        bodyY + (layout.bodyHeight - drawHeight) / 2,
        drawWidth,
        drawHeight
      );
    } else {
      const structured = layout.model.kind === "code" || layout.model.kind === "table";
      context.fillStyle = structured ? "#15242b" : "#f2f6f6";
      context.fillRect(x + 1, bodyY + 1, width - 2, layout.bodyHeight - 1);
      context.fillStyle = structured ? "#f3f8f7" : "#4f646d";
      context.font = structured
        ? '12px Consolas,"Microsoft YaHei",monospace'
        : '13px "Segoe UI","Microsoft YaHei",sans-serif';
      layout.bodyLines.forEach((line, index) => context.fillText(line, x + 12, bodyY + 20 + index * 18));
      if (layout.bodyTruncated) {
        context.fillStyle = structured ? "#8de0d2" : "#087a6f";
        context.font = '700 11px "Segoe UI","Microsoft YaHei",sans-serif';
        context.fillText("完整文本请使用页面上的“复制”按钮", x + 12, bodyY + layout.bodyHeight - 10);
      }
    }
    if (layout.captionLines.length) {
      const captionY = bodyY + layout.bodyHeight;
      context.strokeStyle = "#c9d6da";
      context.beginPath();
      context.moveTo(x, captionY + .5);
      context.lineTo(x + width, captionY + .5);
      context.stroke();
      context.fillStyle = "#637780";
      context.font = '12px "Segoe UI","Microsoft YaHei",sans-serif';
      layout.captionLines.forEach((line, index) => context.fillText(line, x + 12, captionY + 17 + index * 18));
    }
  }

  async function renderColumn(column) {
    await document.fonts.ready;
    const models = await collectCards(column);
    const naturalWidth = 420;
    const cardWidth = naturalWidth - 24;
    const measureCanvas = document.createElement("canvas");
    const measureContext = measureCanvas.getContext("2d");
    if (!measureContext) throw new Error("浏览器未提供文字测量画布");
    const layouts = models.map((model) => makeCardLayout(measureContext, model, cardWidth));
    measureContext.font = '700 18px "Segoe UI","Microsoft YaHei",sans-serif';
    const title = textWithoutControls(column.querySelector(":scope > h3"));
    const heading = wrapText(measureContext, title, naturalWidth - 24, 3);
    const headingHeight = Math.max(54, 20 + heading.lines.length * 24);
    const naturalHeight = Math.ceil(headingHeight + 12 + layouts.reduce((sum, layout) => sum + layout.height + 12, 0));
    const maximumDimension = 30000;
    const maximumPixels = 64000000;
    const scale = Math.min(
      1.5,
      maximumDimension / naturalWidth,
      maximumDimension / naturalHeight,
      Math.sqrt(maximumPixels / (naturalWidth * naturalHeight))
    );
    const outputWidth = Math.max(1, Math.floor(naturalWidth * scale));
    const outputHeight = Math.max(1, Math.floor(naturalHeight * scale));
    const canvas = document.createElement("canvas");
    canvas.width = outputWidth;
    canvas.height = outputHeight;
    const context = canvas.getContext("2d", { alpha: false });
    if (!context) throw new Error("浏览器未提供 2D 画布");
    context.scale(scale, scale);
    context.fillStyle = "#f8fafb";
    context.fillRect(0, 0, naturalWidth, naturalHeight);
    context.fillStyle = "#e5f2ef";
    context.fillRect(0, 0, naturalWidth, headingHeight);
    context.fillStyle = "#153039";
    context.font = '700 18px "Segoe UI","Microsoft YaHei",sans-serif';
    heading.lines.forEach((line, index) => context.fillText(line, 12, 26 + index * 24));
    let y = headingHeight + 12;
    layouts.forEach((layout) => {
      drawCard(context, layout, 12, y, cardWidth);
      y += layout.height + 12;
    });
    return {
      blob: await canvasToPngBlob(canvas),
      width: outputWidth,
      height: outputHeight,
      scale
    };
  }

  function downloadBlob(blob, fileName) {
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = fileName;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function exportColumn(column, button) {
    const original = "导出长图";
    button.disabled = true;
    button.textContent = "生成中…";
    try {
      const result = await renderColumn(column);
      const stepNumber = String((document.getElementById("stepNumber") || {}).textContent || "步骤").trim();
      const title = textWithoutControls(column.querySelector(":scope > h3"));
      downloadBlob(result.blob, safeFileName(stepNumber + "-" + title + "-长图.png"));
      button.textContent = "已导出";
      button.dataset.state = "success";
      button.dataset.lastExport = JSON.stringify({ width: result.width, height: result.height, scale: result.scale });
    } catch (error) {
      console.error("长图导出失败", error);
      button.textContent = "导出失败";
      button.dataset.state = "error";
    } finally {
      window.setTimeout(() => {
        button.textContent = original;
        button.disabled = false;
        delete button.dataset.state;
      }, 1800);
    }
  }

  function enhanceColumn(column) {
    if (column.dataset.deckExportEnhanced === VERSION) return;
    const heading = column.querySelector(":scope > h3");
    if (!heading) return;
    column.dataset.deckExportEnhanced = VERSION;
    heading.classList.add("deck-column-heading");
    wrapHeadingText(heading, "deck-column-title");
    const button = makeButton("导出长图", "一键导出本栏全部阶段卡片", "deck-export-button");
    button.addEventListener("click", () => exportColumn(column, button));
    heading.appendChild(button);
  }

  function enhance() {
    installStyle();
    document.querySelectorAll("#evidenceStage pre.evidence-code, #evidenceStage table.evidence-table")
      .forEach(enhanceCopyNode);
    document.querySelectorAll("#evidenceStage .comparison-column").forEach(enhanceColumn);
  }

  function start() {
    enhance();
    const stage = document.getElementById("evidenceStage");
    if (!stage) return;
    const observer = new MutationObserver(() => enhance());
    observer.observe(stage, { childList: true, subtree: true });
  }

  window.PipelineStepDeckEnhancements = Object.freeze({ version: VERSION, enhance });
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
}());

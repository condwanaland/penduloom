(() => {
  "use strict";

  function initialisePenduloom() {

  const canvas = document.getElementById("pendulum-canvas");
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  const elapsedNode = document.getElementById("elapsed-readout");
  const velocityNode = document.getElementById("velocity-readout");

  const state = {
    running: false,
    trace: true,
    showPendulum: true,
    elapsed: 0,
    lastFrame: null,
    lastTip: null,
    velocity: 0,
    width: 0,
    height: 0,
    dpr: 1,
    trajectory: null,
    trail: [],
    batchRequested: false,
    messageNonce: 0
  };

  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

  function resize() {
    const rect = canvas.getBoundingClientRect();
    state.dpr = Math.min(window.devicePixelRatio || 1, 2);
    state.width = rect.width;
    state.height = rect.height;
    canvas.width = Math.round(rect.width * state.dpr);
    canvas.height = Math.round(rect.height * state.dpr);
    ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0);
    draw();
  }

  function viewportTransform(reach) {
    const compact = state.width < 700;
    const horizontalInset = compact ? 28 : 44;
    const topInset = compact ? 88 : 104;
    const bottomInset = compact ? 50 : 54;
    const origin = {
      x: state.width / 2,
      y: (topInset + state.height - bottomInset) / 2
    };
    const availableRadius = Math.max(24, Math.min(
      origin.x - horizontalInset,
      state.width - horizontalInset - origin.x,
      origin.y - topInset,
      state.height - bottomInset - origin.y
    ));

    return {
      origin,
      scale: Math.min(1.18, availableRadius / Math.max(reach, 1))
    };
  }

  function toScreen(point, reach) {
    const transform = viewportTransform(reach);
    return {
      x: transform.origin.x + point.x * transform.scale,
      y: transform.origin.y + point.y * transform.scale
    };
  }

  function modelFrameAt(elapsed) {
    const trajectory = state.trajectory;
    if (!trajectory || trajectory.x.length === 0) return null;

    const localFrame = elapsed * trajectory.fps - trajectory.startFrame;
    const lower = clamp(Math.floor(localFrame), 0, trajectory.x.length - 1);
    const upper = clamp(lower + 1, 0, trajectory.x.length - 1);
    const mix = clamp(localFrame - Math.floor(localFrame), 0, 1);

    return trajectory.x[lower].map((x, index) => ({
      x: x + (trajectory.x[upper][index] - x) * mix,
      y: trajectory.y[lower][index] +
        (trajectory.y[upper][index] - trajectory.y[lower][index]) * mix
    }));
  }

  function screenFrameAt(elapsed) {
    const modelPoints = modelFrameAt(elapsed);
    if (!modelPoints || !state.trajectory) return null;
    return {
      points: modelPoints.map((point) => toScreen(point, state.trajectory.reach)),
      scale: viewportTransform(state.trajectory.reach).scale
    };
  }

  function drawBackground() {
    ctx.fillStyle = "#f4f5f7";
    ctx.fillRect(0, 0, state.width, state.height);
  }

  function drawGrid() {
    ctx.save();
    ctx.strokeStyle = "rgba(51, 65, 85, 0.07)";
    ctx.lineWidth = 1;
    const spacing = 44;
    for (let x = 0.5; x < state.width; x += spacing) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, state.height);
      ctx.stroke();
    }
    for (let y = 0.5; y < state.height; y += spacing) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(state.width, y);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawTrail() {
    if (state.trail.length < 2) return;
    ctx.save();
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    for (let i = 1; i < state.trail.length; i += 1) {
      const from = state.trail[i - 1];
      const to = state.trail[i];
      if (!from || !to) continue;
      const fromScreen = toScreen(from, from.reach);
      const toScreenPoint = toScreen(to, to.reach);
      const alpha = 0.16 + (i / state.trail.length) * 0.54;
      ctx.strokeStyle = `rgba(180, 83, 9, ${alpha})`;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(fromScreen.x, fromScreen.y);
      ctx.lineTo(toScreenPoint.x, toScreenPoint.y);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawLinkage(points, scale) {
    ctx.save();
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    for (let i = 0; i < points.length - 1; i += 1) {
      ctx.shadowColor = "rgba(0, 0, 0, 0.45)";
      ctx.shadowBlur = 12;
      ctx.strokeStyle = "#334155";
      ctx.lineWidth = Math.max(2.5, 4 * scale);
      ctx.beginPath();
      ctx.moveTo(points[i].x, points[i].y);
      ctx.lineTo(points[i + 1].x, points[i + 1].y);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }

    points.forEach((point, index) => {
      const isOrigin = index === 0;
      const isTip = index === points.length - 1;
      const color = isOrigin
        ? "#334155"
        : state.trajectory.colors[index - 1];
      const radius = isOrigin ? 8 : isTip ? 8 : 6;

      ctx.beginPath();
      ctx.fillStyle = "#f4f5f7";
      ctx.arc(point.x, point.y, radius + 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.fillStyle = color;
      ctx.shadowColor = color;
      ctx.shadowBlur = isTip ? 18 : 8;
      ctx.arc(point.x, point.y, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
      ctx.beginPath();
      ctx.fillStyle = "rgba(255,255,255,.74)";
      ctx.arc(point.x - radius * 0.3, point.y - radius * 0.32, radius * 0.25, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.restore();
  }

  function draw() {
    if (!state.width || !state.height) return;
    ctx.clearRect(0, 0, state.width, state.height);
    drawBackground();
    drawGrid();
    drawTrail();

    const frame = screenFrameAt(state.elapsed);
    if (frame && state.showPendulum) drawLinkage(frame.points, frame.scale);
  }

  function updateReadouts() {
    const minutes = Math.floor(state.elapsed / 60);
    const seconds = state.elapsed % 60;
    elapsedNode.textContent = `${String(minutes).padStart(2, "0")}:${seconds.toFixed(2).padStart(5, "0")}`;
    velocityNode.textContent = state.velocity.toFixed(2);
  }

  function requestNextBatch() {
    const trajectory = state.trajectory;
    if (!trajectory || state.batchRequested || !window.Shiny) return;

    const lastFrame = trajectory.startFrame + trajectory.x.length - 1;
    const framesRemaining = lastFrame - state.elapsed * trajectory.fps;
    if (framesRemaining > trajectory.fps * 2) return;

    state.batchRequested = true;
    Shiny.setInputValue("penduloom_batch_request", {
      revision: trajectory.revision,
      startFrame: lastFrame,
      nonce: ++state.messageNonce
    }, { priority: "event" });
  }

  function advanceSimulation(delta) {
    const previousPoints = modelFrameAt(state.elapsed);
    if (!previousPoints || !state.trajectory) return;
    const previousTip = state.lastTip || previousPoints[previousPoints.length - 1];

    state.elapsed += delta;
    const points = modelFrameAt(state.elapsed);
    if (!points) return;
    const tip = points[points.length - 1];
    const dx = tip.x - previousTip.x;
    const dy = tip.y - previousTip.y;
    state.velocity = delta > 0 ? Math.sqrt(dx * dx + dy * dy) / delta / 100 : 0;
    state.lastTip = tip;

    if (state.trace) {
      state.trail.push({ x: tip.x, y: tip.y, reach: state.trajectory.reach });
    }
    requestNextBatch();
    draw();
    updateReadouts();
  }

  function tick(timestamp) {
    if (state.lastFrame === null) state.lastFrame = timestamp;
    const delta = Math.min((timestamp - state.lastFrame) / 1000, 0.05);
    state.lastFrame = timestamp;
    if (state.running) advanceSimulation(delta);
    window.requestAnimationFrame(tick);
  }

  function setRunning(running) {
    state.running = running;
    state.lastFrame = null;
    state.lastTip = null;
    document.body.classList.toggle("simulation-running", running);

    const button = document.getElementById("run_toggle");
    if (button) {
      button.innerHTML = running
        ? '<span><i class="fa-solid fa-pause" role="presentation"></i><span>Pause</span></span>'
        : '<span><i class="fa-solid fa-play" role="presentation"></i><span>Run</span></span>';
      button.setAttribute("aria-label", running ? "Pause" : "Run");
    }
  }

  function reset(_message) {
    setRunning(false);
    state.elapsed = 0;
    state.velocity = 0;
    state.trail = [];
    state.lastTip = null;
    updateReadouts();
    draw();
  }

  function exportImage(_message) {
    draw();
    canvas.toBlob((blob) => {
      if (!blob) return;
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      const timestamp = new Date().toISOString().replaceAll(":", "-").replace("T", "_").slice(0, 19);
      link.href = url;
      link.download = `penduloom-${timestamp}.png`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);

      const button = document.getElementById("export_image");
      if (button) {
        const original = button.innerHTML;
        button.innerHTML = '<span><i class="fa-solid fa-check" role="presentation"></i><span>PNG saved</span></span>';
        window.setTimeout(() => { button.innerHTML = original; }, 1400);
      }
    }, "image/png");
  }

  function receiveTrajectory(message) {
    if (state.trajectory && message.revision < state.trajectory.revision) return;

    if (!message.replace && state.trajectory &&
        message.revision === state.trajectory.revision) {
      const expectedStart = state.trajectory.startFrame + state.trajectory.x.length - 1;
      if (message.startFrame === expectedStart) {
        state.trajectory.x.push(...message.x.slice(1));
        state.trajectory.y.push(...message.y.slice(1));
      }
      state.batchRequested = false;
      return;
    }

    const geometryChanged = state.trajectory &&
      state.trajectory.signature !== message.signature;
    if (geometryChanged && state.trail.length &&
        state.trail[state.trail.length - 1] !== null) {
      state.trail.push(null);
    }

    state.trajectory = {
      revision: message.revision,
      signature: message.signature,
      startFrame: message.startFrame,
      fps: message.fps,
      reach: message.reach,
      colors: message.colors,
      x: message.x,
      y: message.y
    };
    state.trace = message.trace;
    state.showPendulum = message.showPendulum;
    state.batchRequested = false;
    if (message.resetTime) state.elapsed = message.startFrame / message.fps;
    state.lastTip = null;
    draw();
    updateReadouts();
  }

  function registerShinyHandlers() {
    if (!window.Shiny) {
      window.setTimeout(registerShinyHandlers, 25);
      return;
    }
    Shiny.addCustomMessageHandler("penduloom:trajectory", receiveTrajectory);
    Shiny.addCustomMessageHandler("penduloom:running", ({ running }) => setRunning(running));
    Shiny.addCustomMessageHandler("penduloom:reset", reset);
    Shiny.addCustomMessageHandler("penduloom:trace", ({ enabled }) => {
      if (enabled !== state.trace && state.trail.length &&
          state.trail[state.trail.length - 1] !== null) {
        state.trail.push(null);
      }
      state.trace = enabled;
    });
    Shiny.addCustomMessageHandler("penduloom:pendulum", ({ visible }) => {
      state.showPendulum = visible;
      draw();
    });
    Shiny.addCustomMessageHandler("penduloom:step", ({ seconds }) => {
      setRunning(false);
      advanceSimulation(seconds || 1 / 60);
    });
    Shiny.addCustomMessageHandler("penduloom:export", exportImage);
  }

  function sendPlayhead() {
    if (!window.Shiny) return;
    Shiny.setInputValue("penduloom_playhead", state.elapsed, { priority: "event" });
  }

  function clampInputOnCommit(event) {
    const speedMatch = event.target.id?.match(/^speed_(\d+)$/);
    const lengthMatch = event.target.id?.match(/^length_(\d+)$/);
    const value = event.target.valueAsNumber;
    if (!Number.isFinite(value)) return;
    if (speedMatch) event.target.value = String(clamp(value, -1080, 1080));
    if (lengthMatch) event.target.value = String(clamp(value, 35, 220));
  }

  document.addEventListener("input", (event) => {
    const speedMatch = event.target.id?.match(/^speed_(\d+)$/);
    const lengthMatch = event.target.id?.match(/^length_(\d+)$/);
    const value = event.target.valueAsNumber;
    if (!Number.isFinite(value)) return;

    if (speedMatch && (value < -1080 || value > 1080)) {
      event.target.value = String(clamp(value, -1080, 1080));
      event.target.dispatchEvent(new Event("change", { bubbles: true }));
    }

    if (lengthMatch && window.Shiny) {
      Shiny.setInputValue("penduloom_length_edit", {
        index: Number(lengthMatch[1]),
        value: clamp(value, 35, 220),
        playhead: state.elapsed,
        nonce: ++state.messageNonce
      }, { priority: "event" });
    }
  });

  document.addEventListener("change", clampInputOnCommit);
  document.addEventListener("click", (event) => {
    if (event.target.closest("#run_toggle, #step_frame, #reset")) sendPlayhead();
  }, true);
  window.addEventListener("resize", resize);
  window.addEventListener("keydown", (event) => {
    if (event.code === "Space" && !/INPUT|TEXTAREA|SELECT/.test(event.target.tagName)) {
      event.preventDefault();
      sendPlayhead();
      document.getElementById("run_toggle")?.click();
    }
  });

  window.setInterval(() => {
    if (state.running) sendPlayhead();
  }, 500);
  new ResizeObserver(resize).observe(canvas.parentElement);
  registerShinyHandlers();
  resize();
  updateReadouts();
  window.requestAnimationFrame(tick);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialisePenduloom, { once: true });
  } else {
    initialisePenduloom();
  }
})();


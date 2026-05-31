(function () {
  const charts = {};
  const palette = ["#ff6bd6", "#9d6bff", "#6bf0ff", "#ffd166", "#ff6b8a", "#7cffa8", "#c084fc", "#fb923c"];

  function fmtDuration(sec) {
    if (sec == null || sec === "") return "—";
    sec = Number(sec);
    if (Number.isNaN(sec)) return "—";
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    if (m >= 60) return Math.floor(m / 60) + "h " + (m % 60) + "m";
    return m + "m " + s + "s";
  }

  function fmtProps(props) {
    if (!props || typeof props !== "object") return "";
    const parts = [];
    ["rank", "variant", "slot", "feature", "enabled", "price", "uptime_sec", "difficulty", "mode", "pack_id", "tool", "content"].forEach(function (k) {
      if (props[k] !== undefined && props[k] !== null) parts.push(k + ": " + props[k]);
    });
    if (!parts.length) return JSON.stringify(props).slice(0, 80);
    return parts.join(" · ");
  }

  function destroyChart(id) {
    if (charts[id]) {
      charts[id].destroy();
      delete charts[id];
    }
  }

  function renderCharts(data) {
    const series = data.events_over_time || data.events_per_day || [];

    destroyChart("activity");
    charts.activity = new Chart(document.getElementById("activityChart"), {
      type: "line",
      data: {
        labels: series.map(function (r) { return r.bucket || r.day; }),
        datasets: [{
          label: "Events",
          data: series.map(function (r) { return r.total; }),
          borderColor: "#ff6bd6",
          backgroundColor: "rgba(255,107,214,0.12)",
          fill: true,
          tension: 0.35,
        }],
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: "#a894c9" }, grid: { color: "rgba(255,255,255,0.05)" } },
          y: { ticks: { color: "#a894c9" }, grid: { color: "rgba(255,255,255,0.05)" } },
        },
      },
    });

    destroyChart("actions");
    const actions = (data.action_counts || []).filter(function (r) {
      return !["session_heartbeat", "ping"].includes(r.event_name);
    });
    charts.actions = new Chart(document.getElementById("actionsChart"), {
      type: "bar",
      data: {
        labels: actions.map(function (r) { return r.event_name; }),
        datasets: [{
          label: "Count",
          data: actions.map(function (r) { return r.total; }),
          backgroundColor: palette,
          borderRadius: 8,
        }],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: "#a894c9" }, grid: { color: "rgba(255,255,255,0.05)" } },
          y: { ticks: { color: "#a894c9", font: { size: 11 } }, grid: { display: false } },
        },
      },
    });

    destroyChart("rank");
    const ranks = data.purchases_by_rank || [];
    charts.rank = new Chart(document.getElementById("rankChart"), {
      type: "bar",
      data: {
        labels: ranks.map(function (r) { return r.rank; }),
        datasets: [{
          label: "Buys",
          data: ranks.map(function (r) { return r.total; }),
          backgroundColor: palette,
          borderRadius: 8,
        }],
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
          x: { ticks: { color: "#a894c9" }, grid: { display: false } },
          y: { ticks: { color: "#a894c9" }, grid: { color: "rgba(255,255,255,0.05)" } },
        },
      },
    });

    destroyChart("variant");
    const variants = data.purchases_by_variant || [];
    charts.variant = new Chart(document.getElementById("variantChart"), {
      type: "doughnut",
      data: {
        labels: variants.map(function (r) { return r.variant; }),
        datasets: [{
          data: variants.map(function (r) { return r.total; }),
          backgroundColor: palette,
          borderWidth: 0,
        }],
      },
      options: {
        responsive: true,
        plugins: { legend: { position: "bottom", labels: { color: "#a894c9" } } },
      },
    });
  }

  function renderTables(data) {
    const o = data.overview || {};
    const viewer = data.viewer || {};
    const rangeLabel = (data.range && data.range.label) || o.range_label || "range";
    const periodSuffix = rangeLabel.replace(/^Last /i, "");

    const filterUser = document.getElementById("filterUser");
    if (filterUser) {
      filterUser.closest(".filters").style.display = viewer.admin ? "" : "none";
    }

    document.getElementById("statEvents").textContent = o.total_events ?? "—";
    document.getElementById("statEventsPeriod").textContent = o.period_events ?? o.events_24h ?? "—";
    document.getElementById("statBuysPeriod").textContent = o.period_purchases ?? o.purchases_24h ?? "—";
    document.getElementById("statEventsPeriodLabel").textContent = "Events (" + periodSuffix + ")";
    document.getElementById("statBuysPeriodLabel").textContent = "Pack buys (" + periodSuffix + ")";
    document.getElementById("statPlayers").textContent = o.total_players ?? "—";
    document.getElementById("statOnline").textContent = o.active_sessions ?? "—";
    document.getElementById("statUptime").textContent = (o.avg_uptime_min ?? "—") + (o.avg_uptime_min != null ? " min" : "");

    const playersBody = document.getElementById("playersBody");
    playersBody.innerHTML = (data.players || []).map(function (p) {
      const online = Number(p.online) > 0;
      return "<tr><td><strong>" + escapeHtml(p.username) + "</strong></td><td>" + escapeHtml(p.last_seen) + "</td><td>" + p.total_sessions + "</td><td>" + p.total_events + "</td><td><span class=\"badge " + (online ? "online" : "offline") + "\">" + (online ? "online" : "offline") + "</span></td></tr>";
    }).join("") || "<tr><td colspan=\"5\">No players yet</td></tr>";

    const sessionsBody = document.getElementById("sessionsBody");
    sessionsBody.innerHTML = (data.sessions || []).map(function (s) {
      const dur = s.uptime_sec != null ? fmtDuration(s.uptime_sec) : (s.ended_at ? "ended" : "active");
      return "<tr><td>" + escapeHtml(s.username) + "</td><td>" + escapeHtml(s.started_at) + "</td><td>" + dur + "</td><td>" + escapeHtml(s.script_version || "—") + "</td></tr>";
    }).join("") || "<tr><td colspan=\"4\">No sessions yet</td></tr>";

    const eventsBody = document.getElementById("eventsBody");
    eventsBody.innerHTML = (data.recent_events || []).map(function (e) {
      const props = e.props || {};
      return "<tr><td>" + escapeHtml(e.created_at) + "</td><td class=\"event-name\">" + escapeHtml(e.event_name) + "</td><td>" + escapeHtml(e.username || "—") + "</td><td class=\"props-preview\" title=\"" + escapeHtml(JSON.stringify(props)) + "\">" + escapeHtml(fmtProps(props)) + "</td></tr>";
    }).join("") || "<tr><td colspan=\"4\">No events yet — run the script with backend enabled</td></tr>";
  }

  function escapeHtml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  async function load() {
    const range = document.getElementById("timeRange").value;
    const user = document.getElementById("filterUser").value.trim();
    const event = document.getElementById("filterEvent").value;
    let url = "/data.php?range=" + encodeURIComponent(range);
    if (user) url += "&username=" + encodeURIComponent(user);
    if (event) url += "&event=" + encodeURIComponent(event);
    const res = await fetch(url);
    const data = await res.json();
    renderCharts(data);
    renderTables(data);
  }

  document.getElementById("refreshBtn").addEventListener("click", load);
  document.getElementById("timeRange").addEventListener("change", load);
  document.getElementById("filterUser").addEventListener("input", debounce(load, 400));
  document.getElementById("filterEvent").addEventListener("change", load);

  function debounce(fn, ms) {
    let t;
    return function () {
      clearTimeout(t);
      t = setTimeout(fn, ms);
    };
  }

  load();
  setInterval(load, 30000);
})();

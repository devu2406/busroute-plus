/* BusRoute+ frontend
   - `API` mirrors what the backend will do with SQL (JOIN, VIEW, AVG, RANK, trigger...).
   - Step 2 replaces the API bodies with fetch() calls; the UI code stays the same. */

/* ---------- state ---------- */
const state = { lang: "en", view: "find", selectedRoute: null, lastResults: null, trust: 50 };
try { state.trust = +localStorage.getItem("brp_trust") || 50; state.lang = localStorage.getItem("brp_lang") || "en"; } catch (e) {}

const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const t = (k) => (I18N[state.lang][k] ?? I18N.en[k] ?? k);
const stopById = (id) => DB.stops.find((s) => s.id === id);
const routeById = (id) => DB.routes.find((r) => r.id === id);
const stopName = (s) => (state.lang === "ta" ? s.ta : s.en);

/* ---------- API layer (becomes fetch() in step 2) ---------- */
const API = {
  nowMin() { const d = new Date(); return d.getHours() * 60 + d.getMinutes(); },
  toMin(hhmm) { const [h, m] = hhmm.split(":").map(Number); return h * 60 + m; },
  fmt(min) { min = ((Math.round(min) % 1440) + 1440) % 1440; return String(Math.floor(min / 60)).padStart(2, "0") + ":" + String(min % 60).padStart(2, "0"); },

  // Trust-weighted delay: SUM(minutes*trust)/SUM(trust) over recent reports
  weightedDelay(routeId) {
    const rs = DB.reports.filter((r) => r.routeId === routeId && r.type === "delay" && r.ago <= 60);
    const w = rs.reduce((a, r) => a + r.userTrust, 0);
    return w ? Math.round(rs.reduce((a, r) => a + r.minutes * r.userTrust, 0) / w) : 0;
  },
  reportCount(routeId) { return DB.reports.filter((r) => r.routeId === routeId).length; },
  routeCrowd(routeId) {
    const bs = DB.buses.filter((b) => b.routeId === routeId);
    return bs.length ? Math.round(bs.reduce((a, b) => a + b.crowd, 0) / bs.length) : 0;
  },
  crowdLabel(p) { return p < 40 ? ["low", "low"] : p < 70 ? ["med", "medium"] : ["high", "high"]; },

  // Next bus reaching a stop: departures every `freq` min from first departure, offset by travel time
  nextArrival(route, offset) {
    const now = this.nowMin(), first = this.toMin(route.firstDep), last = this.toMin(route.lastDep);
    for (let dep = first; dep <= last; dep += route.freq) {
      if (dep + offset >= now) return dep + offset;
    }
    return null;
  },

  // Fare: CASE on passenger category x number of stages
  fare(hops, category = "general") {
    const f = DB.fareRules, base = f.baseFare + f.perStage * Math.max(hops - 1, 0);
    return Math.round(base * f.categories[category]);
  },

  // Route search (JOIN routes <-> routestops, from_seq < to_seq)
  search(fromText, toText, routeText) {
    const match = (txt) => {
      txt = txt.trim().toLowerCase();
      return txt ? DB.stops.filter((s) => s.en.toLowerCase().includes(txt) || s.ta.includes(txt)).map((s) => s.id) : [];
    };
    const fromIds = match(fromText), toIds = match(toText), rt = routeText.trim().toLowerCase();
    let out = [];
    DB.routes.forEach((r) => {
      if (rt && !r.no.toLowerCase().includes(rt)) return;
      if (!fromIds.length && !toIds.length) { if (rt) out.push({ route: r }); return; }
      const idx = (ids) => r.stops.findIndex(([sid]) => ids.includes(sid));
      const fi = fromIds.length ? idx(fromIds) : 0;
      const ti = toIds.length ? idx(toIds) : r.stops.length - 1;
      if (fi < 0 || ti < 0 || fi >= ti) return;
      out.push({ route: r, fi, ti });
    });
    return out.map((o) => {
      const r = o.route, fi = o.fi ?? 0, ti = o.ti ?? r.stops.length - 1;
      const [fromId, fOff] = r.stops[fi], [toId, tOff] = r.stops[ti];
      const arr = this.nextArrival(r, fOff), delay = this.weightedDelay(r.id);
      return { route: r, fromId, toId, hops: ti - fi, travel: tOff - fOff,
               arrival: arr == null ? null : arr + delay, delay, crowd: this.routeCrowd(r.id) };
    }).sort((a, b) => (a.arrival ?? 1e9) - (b.arrival ?? 1e9));
  },

  // Trigger stand-in: new report -> bump trust, insert report
  submitReport(rep) {
    DB.reports.unshift({ ...rep, userTrust: state.trust, ago: 0 });
    state.trust = Math.min(100, state.trust + 2);
    try { localStorage.setItem("brp_trust", state.trust); } catch (e) {}
  },

  // GROUP BY / HAVING stand-in: stop is verified after 3 confirmations
  confirmStop(stopId) {
    const s = stopById(stopId); s.conf++;
    if (s.conf >= 3) s.verified = 1;
    const p = DB.pendingCorrections.find((c) => c.stopId === stopId);
    if (p) { p.votes = s.conf; if (s.verified) DB.pendingCorrections = DB.pendingCorrections.filter((c) => c !== p); }
    return s;
  },

  // Route ranking (RANK() window) + anomaly detection (AVG + STDDEV, HAVING)
  insights() {
    const rows = DB.routes.map((r) => ({ route: r, avg: this.weightedDelay(r.id), n: this.reportCount(r.id), crowd: this.routeCrowd(r.id) }));
    const mean = rows.reduce((a, x) => a + x.avg, 0) / rows.length;
    const sd = Math.sqrt(rows.reduce((a, x) => a + (x.avg - mean) ** 2, 0) / rows.length);
    rows.forEach((x) => (x.anomaly = sd > 0 && x.avg > mean + sd * 0.8));
    rows.sort((a, b) => a.avg - b.avg).forEach((x, i) => (x.rank = i + 1));
    return { rows, mean: Math.round(mean * 10) / 10 };
  },

  // Active bus position from its progress along the route (for the live map)
  busLatLng(bus) {
    const r = routeById(bus.routeId), pts = r.stops.map(([id]) => stopById(id));
    const f = bus.progress * (pts.length - 1), i = Math.min(Math.floor(f), pts.length - 2), k = f - i;
    return [pts[i].lat + (pts[i + 1].lat - pts[i].lat) * k, pts[i].lng + (pts[i + 1].lng - pts[i].lng) * k];
  },
};

/* ---------- map ---------- */
let map, stopLayer, routeLayer, busLayer = {};
function initMap() {
  map = L.map("map", { zoomControl: true }).setView([12.95, 80.12], 10);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19, attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map);
  stopLayer = L.layerGroup().addTo(map);
  routeLayer = L.layerGroup().addTo(map);
  drawStops();
  DB.buses.forEach((b) => {
    const r = routeById(b.routeId);
    const icon = L.divIcon({ className: "", iconSize: [30, 30], html: `<div class="bus-marker" style="background:${r.color}">${r.no}</div>` });
    busLayer[b.id] = L.marker(API.busLatLng(b), { icon }).addTo(map).on("click", () => openRoute(r.id));
  });
  setInterval(moveBuses, 3000);
}
function drawStops() {
  stopLayer.clearLayers();
  DB.stops.forEach((s) => {
    L.circleMarker([s.lat, s.lng], { radius: 5, color: s.verified ? "#14213d" : "#e08a1e", weight: 2, fillColor: "#fff", fillOpacity: 1 })
      .bindTooltip(stopName(s)).addTo(stopLayer);
  });
}
function moveBuses() {
  DB.buses.forEach((b) => {
    b.progress += 0.012; if (b.progress > 1) b.progress = 0;
    busLayer[b.id].setLatLng(API.busLatLng(b));
  });
}
function drawRoute(route) {
  routeLayer.clearLayers();
  const pts = route.stops.map(([id]) => { const s = stopById(id); return [s.lat, s.lng]; });
  const line = L.polyline(pts, { color: route.color, weight: 5, opacity: 0.85 }).addTo(routeLayer);
  map.fitBounds(line.getBounds(), { padding: [40, 40] });
}

/* ---------- helpers ---------- */
function toast(msg) {
  const el = $("#toast"); el.textContent = msg; el.hidden = false;
  clearTimeout(toast.t); toast.t = setTimeout(() => (el.hidden = true), 2600);
}
function crowdPill(p) {
  const [cls, key] = API.crowdLabel(p);
  return `<span class="pill ${cls}">${t(key)} · ${p}% ${t("full")}</span>`;
}
function delayPill(d) { return d > 0 ? `<span class="pill warn">+${d} ${t("min")}</span>` : `<span class="pill ok">${t("onTime")}</span>`; }

/* ---------- views ---------- */
function setView(v) {
  state.view = v;
  $$("#nav button").forEach((b) => b.classList.toggle("active", b.dataset.view === v));
  const mapView = v === "find" || v === "live";
  $("#split").hidden = !mapView; $("#view-report").hidden = v !== "report"; $("#view-insights").hidden = v !== "insights";
  $("#side-find").hidden = v !== "find"; $("#side-live").hidden = v !== "live";
  if (mapView) setTimeout(() => map.invalidateSize(), 50);
  if (v === "find") renderFind();
  if (v === "live") renderLive();
  if (v === "report") renderReport();
  if (v === "insights") renderInsights();
}

/* Find Bus */
function renderFind() {
  const body = $("#findBody");
  if (state.selectedRoute) return renderRouteDetail(state.selectedRoute);
  if (!state.lastResults) { body.innerHTML = `<div class="empty">${t("startHint")}</div>`; return; }
  if (!state.lastResults.length) { body.innerHTML = `<div class="empty">${t("noResult")}</div>`; return; }
  body.innerHTML = state.lastResults.map((x, i) => {
    const r = x.route, arrive = x.arrival == null ? "–" : API.fmt(x.arrival);
    return `<div class="card click" data-i="${i}">
      <div class="card-head">
        <div class="badge-no" style="background:${r.color}">${r.no}</div>
        <div><div class="title">${r.name}</div>
        <div class="sub">${stopName(stopById(x.fromId))} → ${stopName(stopById(x.toId))}</div></div>
      </div>
      <div class="meta">
        <span>⏱ ${t("eta")} <b>${arrive}</b></span>
        <span>₹ ${t("fare")} <b>${API.fare(x.hops)}</b></span>
        <span>${x.hops} ${t("stops")}</span>
        ${delayPill(x.delay)} ${crowdPill(x.crowd)}
        ${r.diverted ? `<span class="pill warn">⚠ ${t("diversion")}</span>` : ""}
      </div></div>`;
  }).join("");
  $$("#findBody .card").forEach((c) => (c.onclick = () => openRoute(state.lastResults[+c.dataset.i].route.id, state.lastResults[+c.dataset.i])));
}
function openRoute(routeId, ctx) {
  state.selectedRoute = { routeId, ctx: ctx || null };
  if (state.view !== "find") setView("find"); else renderFind();
}
function renderRouteDetail({ routeId, ctx }) {
  const r = routeById(routeId), body = $("#findBody");
  drawRoute(r);
  const delay = API.weightedDelay(r.id), div = DB.diversions.find((d) => d.routeId === r.id);
  const hitIds = ctx ? [ctx.fromId, ctx.toId] : [];
  const base = API.nextArrival(r, 0);
  const stopsHtml = r.stops.map(([sid, off]) => {
    const s = stopById(sid);
    const time = base == null ? "–" : API.fmt(base + off + delay);
    return `<li class="${hitIds.includes(sid) ? "hit" : ""}">
      <span class="t">${time}</span><div>${stopName(s)}</div>
      <div class="ta">${state.lang === "ta" ? s.en : s.ta}
        · ${s.verified ? `<span class="verified">✔ ${t("verified")}</span>` : `<span class="unverified">${t("unverified")} (${s.conf}/3)</span>`}
        ${s.verified ? "" : `<button class="ghost" data-confirm="${s.id}" style="padding:2px 8px;margin-left:6px;font-size:12px">${t("confirm")}</button>`}
      </div></li>`;
  }).join("");
  const fares = ["general", "student", "senior", "woman"].map((c) => `${t(c)}: ₹${API.fare(ctx ? ctx.hops : r.stops.length - 1, c)}`).join(" · ");
  body.innerHTML = `
    <button class="back" id="backBtn">${t("back")}</button>
    <div class="card"><div class="card-head">
      <div class="badge-no" style="background:${r.color}">${r.no}</div>
      <div><div class="title">${r.name}</div>
      <div class="sub">${t("every")} ${r.freq} ${t("min")} · ${t("firstLast")}: ${r.firstDep} / ${r.lastDep}</div></div></div>
      <div class="meta">${delayPill(delay)} ${crowdPill(API.routeCrowd(r.id))}</div>
      <div class="meta">₹ ${fares}</div>
    </div>
    ${div ? `<div class="card" style="background:var(--gold-soft);border-color:#f0d58a">⚠ <b>${t("diversion")}:</b> ${state.lang === "ta" ? div.note_ta : div.note_en}</div>` : ""}
    <h3>${t("stopList")}</h3>
    <ul class="timeline">${stopsHtml}</ul>`;
  $("#backBtn").onclick = () => { state.selectedRoute = null; routeLayer.clearLayers(); renderFind(); };
  $$("[data-confirm]").forEach((b) => (b.onclick = () => {
    const s = API.confirmStop(+b.dataset.confirm); drawStops(); renderRouteDetail(state.selectedRoute);
    toast(s.verified ? `${stopName(s)} ✔ ${t("verified")}` : t("thanks"));
  }));
}

/* Live map list (like a VIEW over buses + routes) */
function renderLive() {
  const q = $("#liveSearch").value.trim().toLowerCase();
  if (state.selectedRoute) { state.selectedRoute = null; routeLayer.clearLayers(); }
  const list = DB.routes.filter((r) => !q || r.no.toLowerCase().includes(q) || r.name.toLowerCase().includes(q) ||
    r.stops.some(([id]) => { const s = stopById(id); return s.en.toLowerCase().includes(q) || s.ta.includes(q); }));
  $("#liveList").innerHTML = list.map((r) => {
    const active = DB.buses.filter((b) => b.routeId === r.id).length, first = stopById(r.stops[0][0]), last = stopById(r.stops.at(-1)[0]);
    return `<div class="card click" data-id="${r.id}">
      <div class="card-head"><div class="badge-no" style="background:${r.color}">${r.no}</div>
      <div><div class="title">${r.name}</div><div class="sub">${stopName(first)} → ${stopName(last)}</div></div></div>
      <div class="meta"><span>🚌 ${active} ${t("activeBuses")}</span>${delayPill(API.weightedDelay(r.id))}${crowdPill(API.routeCrowd(r.id))}</div></div>`;
  }).join("") || `<div class="empty">${t("noResult")}</div>`;
  $$("#liveList .card").forEach((c) => (c.onclick = () => openRoute(+c.dataset.id)));
}

/* Report */
function renderReport() {
  const routeOpts = DB.routes.map((r) => `<option value="${r.id}">${r.no} – ${r.name}</option>`).join("");
  $("#view-report").innerHTML = `
    <h2>${t("reportTitle")}</h2><div class="sub">${t("reportSub")}</div>
    <form class="form" id="reportForm">
      <div><label>${t("reportType")}</label>
        <div class="seg">
          ${[["delay", "rDelay"], ["crowd", "rCrowd"], ["stop", "rStop"], ["diversion", "rDiv"]]
            .map(([v, k], i) => `<label><input type="radio" name="type" value="${v}" ${i === 0 ? "checked" : ""}>${t(k)}</label>`).join("")}
        </div></div>
      <div class="grid2">
        <div><label>${t("route")}</label><select id="rRoute" required><option value="">${t("pickRoute")}</option>${routeOpts}</select></div>
        <div><label>${t("stop")}</label><select id="rStop"></select></div>
      </div>
      <div id="dynField"></div>
      <div><label>${t("details")}</label><textarea id="rNote" rows="3" maxlength="200"></textarea></div>
      <button class="primary" type="submit">${t("submit")}</button>
    </form>`;
  const dyn = () => {
    const type = $('input[name="type"]:checked').value;
    $("#dynField").innerHTML =
      type === "delay" ? `<label>${t("minutesLate")}: <b id="mv">10</b></label><input type="range" id="rMin" min="1" max="60" value="10">` :
      type === "crowd" ? `<label>${t("crowdLevel")}: <b id="cv">50</b>%</label><input type="range" id="rCrowd" min="0" max="100" value="50">` : "";
    const rg = $("#rMin") || $("#rCrowd"); if (rg) rg.oninput = () => ($("#mv") || $("#cv")).textContent = rg.value;
  };
  $$('input[name="type"]').forEach((i) => (i.onchange = dyn)); dyn();
  $("#rRoute").onchange = (e) => {
    const r = routeById(+e.target.value);
    $("#rStop").innerHTML = r ? r.stops.map(([id]) => `<option value="${id}">${stopName(stopById(id))}</option>`).join("") : "";
  };
  $("#reportForm").onsubmit = (e) => {
    e.preventDefault();
    const type = $('input[name="type"]:checked').value, routeId = +$("#rRoute").value;
    if (!routeId) return toast(t("pickRoute"));
    API.submitReport({ routeId, type, minutes: +($("#rMin")?.value || 0), crowd: +($("#rCrowd")?.value || 0), stopId: +$("#rStop").value, note: $("#rNote").value });
    if (type === "crowd") DB.buses.filter((b) => b.routeId === routeId).forEach((b) => (b.crowd = +$("#rCrowd").value));
    $("#trustValue").textContent = state.trust; toast(t("thanks")); e.target.reset(); renderReport();
  };
}

/* Insights */
function renderInsights() {
  const { rows, mean } = API.insights();
  const verified = DB.stops.filter((s) => s.verified).length, maxD = Math.max(...rows.map((x) => x.avg), 1);
  $("#view-insights").innerHTML = `
    <h2>${t("insightsTitle")}</h2><div class="sub">${t("insightsSub")}</div>
    <div class="kpis">
      <div class="kpi"><b>${DB.buses.length}</b><span>${t("kpiBuses")}</span></div>
      <div class="kpi"><b>${DB.routes.length}</b><span>${t("kpiRoutes")}</span></div>
      <div class="kpi"><b>${verified}/${DB.stops.length}</b><span>${t("kpiVerified")}</span></div>
      <div class="kpi"><b>${mean} ${t("min")}</b><span>${t("avgDelay")}</span></div>
      <div class="kpi"><b>${DB.reports.length}</b><span>${t("kpiReports")}</span></div>
    </div>
    <h3>${t("routeRanking")}</h3>
    <table><thead><tr><th>${t("rank")}</th><th>${t("route")}</th><th>${t("weighted")}</th><th>${t("reports")}</th><th>${t("crowd")}</th><th>${t("anomaly")}</th></tr></thead><tbody>
    ${rows.map((x) => `<tr><td>#${x.rank}</td><td><b>${x.route.no}</b> <span class="sub">${x.route.name}</span></td>
      <td><div class="bar"><i style="width:${(x.avg / maxD) * 100}%"></i></div>${x.avg} ${t("min")}</td>
      <td>${x.n}</td><td>${crowdPill(x.crowd)}</td>
      <td>${x.anomaly ? `<span class="pill high">${t("unusual")}</span>` : `<span class="pill low">${t("normal")}</span>`}</td></tr>`).join("")}
    </tbody></table>
    <h3>${t("pending")}</h3>
    ${DB.pendingCorrections.map((c) => `<div class="card"><b>${stopName(stopById(c.stopId))}</b>
      <div class="sub">${c.note}</div><div class="meta"><span class="pill warn">${c.votes}/${c.needed} ${t("votes")}</span></div></div>`).join("") || `<div class="empty">–</div>`}`;
}

/* ---------- i18n + events ---------- */
function applyLang() {
  document.documentElement.lang = state.lang;
  $$("[data-i18n]").forEach((el) => (el.textContent = t(el.dataset.i18n)));
  $$("[data-i18n-ph]").forEach((el) => (el.placeholder = t(el.dataset.i18nPh)));
  $$("#langToggle button").forEach((b) => b.classList.toggle("active", b.dataset.lang === state.lang));
  $("#stopList").innerHTML = DB.stops.map((s) => `<option value="${stopName(s)}">`).join("");
  if (map) drawStops();
}

function init() {
  initMap();
  $("#trustValue").textContent = state.trust;
  applyLang();
  $("#nav").onclick = (e) => { const b = e.target.closest("button"); if (b) { state.selectedRoute = null; setView(b.dataset.view); } };
  $("#langToggle").onclick = (e) => {
    const b = e.target.closest("button"); if (!b) return;
    state.lang = b.dataset.lang; try { localStorage.setItem("brp_lang", state.lang); } catch (_) {}
    applyLang(); setView(state.view);
  };
  $("#searchForm").onsubmit = (e) => {
    e.preventDefault(); state.selectedRoute = null; routeLayer.clearLayers();
    state.lastResults = API.search($("#fromInput").value, $("#toInput").value, $("#routeInput").value);
    renderFind();
  };
  $("#swapBtn").onclick = () => { const a = $("#fromInput"), b = $("#toInput"); [a.value, b.value] = [b.value, a.value]; };
  $("#liveSearch").oninput = renderLive;
  setView("find");
}
document.addEventListener("DOMContentLoaded", init);

window.BUS_BACKEND_DATA = {
  routes: [],
  stops: [],
  buses: [],
  loaded: false
};

async function loadBackendData() {
  try {
    const [routes, stops, buses] = await Promise.all([
      BusAPI.getRoutes(),
      BusAPI.getStops(),
      BusAPI.getBuses()
    ]);

    window.BUS_BACKEND_DATA.routes = routes;
    window.BUS_BACKEND_DATA.stops = stops;
    window.BUS_BACKEND_DATA.buses = buses;
    window.BUS_BACKEND_DATA.loaded = true;

    console.log("Backend data ready:", window.BUS_BACKEND_DATA);
  } catch (error) {
    console.error("Could not load backend data:", error);
  }
}

loadBackendData();

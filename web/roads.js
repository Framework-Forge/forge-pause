// Road graph and route algorithm adapted from the supplied PLT reference.
const ROADS = { ready: false, n: 0, x: null, y: null, z: null, f: null, off: null, to: null, lanes: null };
fetch('assets/roads.bin').then(r => r.arrayBuffer()).then(buf => {
  const dv = new DataView(buf);
  if (String.fromCharCode(dv.getUint8(0), dv.getUint8(1), dv.getUint8(2), dv.getUint8(3)) !== 'XDR2') return;
  const n = dv.getUint32(4, true), m = dv.getUint32(8, true);
  let o = 12;
  const raw = new Int16Array(buf.slice(o, o + n * 6)); o += n * 6;
  ROADS.x = new Float32Array(n); ROADS.y = new Float32Array(n); ROADS.z = new Float32Array(n);
  for (let i = 0; i < n; i++) { ROADS.x[i] = raw[i * 3] / 2; ROADS.y[i] = raw[i * 3 + 1] / 2; ROADS.z[i] = raw[i * 3 + 2] / 2; }
  ROADS.f = new Uint8Array(buf.slice(o, o + n)); o += n;
  ROADS.off = new Uint32Array(buf.slice(o, o + (n + 1) * 4)); o += (n + 1) * 4;
  ROADS.to = new Uint32Array(buf.slice(o, o + m * 4)); o += m * 4;
  ROADS.lanes = new Uint8Array(buf.slice(o, o + m));
  ROADS.n = n; ROADS.ready = true;
  window.dispatchEvent(new Event('forge-roads-ready'));
}).catch(() => {});

// Point de route le plus proche (routes du GPS, hors eau).
function nearestRoad(x, y) {
  const R = ROADS; let best = -1, bd = Infinity;
  for (let i = 0; i < R.n; i++) {
    if ((R.f[i] & 3) !== 1) continue;
    const dx = R.x[i] - x, dy = R.y[i] - y, d = dx * dx + dy * dy;
    if (d < bd) { bd = d; best = i; }
  }
  return best;
}

// Vitesse (m/s) selon le type de route, comme le GPS de GTA qui cherche le trajet le plus rapide :
// flags 1 gps, 2 eau, 4 autoroute, 8 carrefour, 16 petite route, 32 terre, 64 feu rouge.
const ROAD_SPEED = { freeway: 30, main: 17, back: 12, gravel: 6, offGps: 4, multiLane: 1.25 };
const JUNCTION_S = 2, LIGHT_S = 5;
function roadSpeed(f, lanes) {
  if (!(f & 1)) return ROAD_SPEED.offGps;
  if (f & 4) return ROAD_SPEED.freeway;
  if (f & 32) return ROAD_SPEED.gravel;
  return (f & 16 ? ROAD_SPEED.back : ROAD_SPEED.main) * (lanes >= 2 ? ROAD_SPEED.multiLane : 1);
}

// A* sur le temps de trajet : distance / vitesse de la route, + temps perdu aux carrefours et feux.
// Mode de calcul : 'fast' = le plus rapide (comme GTA), 'short' = le plus court en mètres,
// 'nohw' = le plus rapide sans autoroute (vélo, à pied), 'hw' = par l'autoroute dès que possible.
// Choisi dans la ligne du point GPS.
let routeMode = 'fast';

function findRoute(ax, ay, bx, by, mode = routeMode) {
  const R = ROADS, s = nearestRoad(ax, ay), t = nearestRoad(bx, by);
  if (s < 0 || t < 0) return null;
  const n = R.n, g = new Float64Array(n).fill(Infinity), par = new Int32Array(n).fill(-1), done = new Uint8Array(n);
  const heap = [], hf = [];
  const push = (i, f) => {
    heap.push(i); hf.push(f); let k = heap.length - 1;
    while (k > 0) { const p = (k - 1) >> 1; if (hf[p] <= hf[k]) break; [heap[p], heap[k]] = [heap[k], heap[p]]; [hf[p], hf[k]] = [hf[k], hf[p]]; k = p; }
  };
  const pop = () => {
    const top = heap[0], li = heap.pop(), lf = hf.pop();
    if (heap.length) {
      heap[0] = li; hf[0] = lf; let k = 0;
      for (;;) {
        const l = k * 2 + 1, r = l + 1; let s2 = k;
        if (l < heap.length && hf[l] < hf[s2]) s2 = l;
        if (r < heap.length && hf[r] < hf[s2]) s2 = r;
        if (s2 === k) break;
        [heap[s2], heap[k]] = [heap[k], heap[s2]]; [hf[s2], hf[k]] = [hf[k], hf[s2]]; k = s2;
      }
    }
    return top;
  };
  const tx = R.x[t], ty = R.y[t];
  const HW_SPEED = 55; // mode autoroute : l'autoroute compte comme beaucoup plus rapide
  const hDiv = mode === 'short' ? 1 : mode === 'hw' ? HW_SPEED : ROAD_SPEED.freeway; // estimation du reste, jamais surestimée
  g[s] = 0; push(s, 0);
  while (heap.length) {
    const a = pop();
    if (done[a]) continue;
    done[a] = 1;
    if (a === t) break;
    for (let e = R.off[a]; e < R.off[a + 1]; e++) {
      const b = R.to[e];
      if (done[b] || (R.f[b] & 2)) continue;
      const dx = R.x[b] - R.x[a], dy = R.y[b] - R.y[a], dz = R.z[b] - R.z[a];
      const fb = R.f[b];
      const len = Math.sqrt(dx * dx + dy * dy + dz * dz);
      let w;
      if (mode === 'short') w = len * ((fb & 1) ? 1 : 3); // mètres (chemins hors GPS pénalisés)
      else {
        const sp = mode === 'nohw' && (fb & 4) ? ROAD_SPEED.offGps : mode === 'hw' && (fb & 4) && (fb & 1) ? HW_SPEED : roadSpeed(fb, R.lanes[e]);
        w = len / sp + (fb & 8 ? JUNCTION_S : 0) + (fb & 64 ? LIGHT_S : 0);
      }
      const ng = g[a] + w;
      // estimation du reste : à vol d'oiseau à la vitesse maximale (garde le trajet optimal)
      if (ng < g[b]) { g[b] = ng; par[b] = a; push(b, ng + Math.hypot(tx - R.x[b], ty - R.y[b]) / hDiv); }
    }
  }
  if (par[t] < 0 && s !== t) return null;
  const path = [];
  for (let i = t; i >= 0; i = par[i]) path.push(i);
  path.reverse();
  let len = 0;
  for (let i = 1; i < path.length; i++) len += Math.hypot(R.x[path[i]] - R.x[path[i - 1]], R.y[path[i]] - R.y[path[i - 1]]);
  let time = g[t];
  if (mode === 'short') { // g = mètres : on estime le temps sur les routes choisies
    time = 0;
    for (let i = 1; i < path.length; i++) {
      const a = path[i - 1], b = path[i], fb = R.f[b];
      time += Math.hypot(R.x[b] - R.x[a], R.y[b] - R.y[a]) / roadSpeed(fb, 1) + (fb & 8 ? JUNCTION_S : 0) + (fb & 64 ? LIGHT_S : 0);
    }
  }
  return { path, len, time }; // time : secondes estimées en voiture
}
window.ForgeRoads = { find: findRoute, get ready() { return ROADS.ready; }, points(result) { return result.path.map(i => ({ x: ROADS.x[i], y: ROADS.y[i], z: ROADS.z[i] })); } };

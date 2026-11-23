// soak.mjs: long games, WebAssembly vs native, compared every turn.
//
//   node soak.mjs <gtnw.wasm> <gtnw-golden binary> <repo root> [year:seedhex:turns[:rules[:player[:turnLength[:hawk]]]]] ...]
//
// Plays each game in both engines at once: the WebAssembly engine under Node, and GTNWCore natively through
// `gtnw-golden --serve` (the same bridge over stdin/stdout). The seat is automated the way Watch mode plays it: the
// crisis on the desk gets its likeliest option, then one presidential order per turn from a fixed rotation (a
// "hawk" game adds strikes and, every 40 turns, a nuclear launch), then End Turn. After every call the two replies
// (events and state) must be identical (a crisis's epigraph aside: it is picked by the crisis's random UUID), and after every turn the full saved game (`save`, the whole GameState
// with the RNG) must match once wall-clock fields, random UUIDs and hash order are normalized. Exits 1 on the first divergence,
// with its path. Default: DEFAULT_GAMES below.
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { loadGTNW, RESOURCE_FILES } from '../js/gtnw.mjs';
import { firstDifference } from './compare.mjs';

/** Four eras, 330 weekly turns each (seeds and seats picked so the game lasts: most games end sooner, at an election,
 *  a no-confidence vote, five years of peace or the end of the world), and a monthly hawk game. */
const DEFAULT_GAMES = ['1789:111789:330:full:GBR:week:hawk', '1914:19141:330:full:USA:week', '1962:551962:330:full:USA:week',
  '2025:112025:330:full:CHN:week', '1962:bad:150:full:USA:month:hawk'];
const [wasmPath, nativeBin, root, ...specs] = process.argv.slice(2);
if (!wasmPath || !nativeBin || !root) {
  console.error('usage: node soak.mjs <gtnw.wasm> <gtnw-golden> <repo root> [year:seedhex:turns[:rules[:player[:turnLength[:hawk]]]]] ...]');
  process.exit(2);
}
const games = (specs.length ? specs : DEFAULT_GAMES).map((s) => {
  const [year, seed, turns, rules = 'full', player = 'USA', turnLength = 'month', hawk] = s.split(':');
  return { year: Number(year), seed, turns: Number(turns), rules, player, turnLength, hawk: hawk === 'hawk' };
});

// The orders, in turn order (wrapping). Peaceful games cover diplomacy, trade, aid, intelligence and covert work;
// hawk games add force.
const DOVE = ['Send Ambassador', 'Trade Deal', 'Economic Aid', 'Arrange Summit', 'Investment Package', 'Military Exercise',
  'Deploy Spies', 'Satellite Recon', 'Economic Sanctions', 'Cyber Attack', 'Fund Opposition', 'Food Aid', 'Joint Statement',
  'Impose Tariffs', 'Military Aid', 'Sell Weapons', 'Steal Technology', 'Defensive Pact', 'Demand Apology', 'Tech Assistance'];
const HAWK = [...DOVE, 'Air Strike', 'Naval Blockade', 'Ground Invasion', 'Special Forces', 'Bombardment', 'Stage Coup'];

// ---- the native engine: gtnw-golden --serve ----
function serve() {
  const child = spawn(nativeBin, [root, '--serve'], { stdio: ['pipe', 'pipe', 'inherit'] });
  const lines = createInterface({ input: child.stdout, crlfDelay: Infinity })[Symbol.asyncIterator]();
  return {
    child,
    async call(op, payload = '') {
      child.stdin.write(`${op} ${payload}\n`);
      const { value, done } = await lines.next();
      if (done) throw new Error('native engine exited');
      return value;
    },
  };
}
const native = serve();
const nativeCall = native.call;

// ---- the WebAssembly engine (or, with "native" for the .wasm, a second native process: a baseline that shows
// what differs between any two runs) ----
const OP = { newGame: 1, act: 2, endTurn: 3, snapshot: 4, save: 5 };
let otherCall;
if (wasmPath === 'native') {
  otherCall = serve().call;
} else {
  const resources = Object.fromEntries(Object.entries(RESOURCE_FILES).map(([n, p]) => [n, readFileSync(join(root, p))]));
  const wasm = await loadGTNW(readFileSync(wasmPath), resources, { log: (_fd, t) => process.stderr.write(`wasm: ${t}\n`) });
  otherCall = async (op, payload) => wasm.raw(op, op === OP.newGame || op === OP.act ? payload : undefined);
}

// ---- comparison ----
const UUID = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/i;
/** Wall-clock times (when a log line was written, when the session started): ISO dates within a week of now. */
const ISO = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/;
const isWallClock = (s) => ISO.test(s) && Math.abs(Date.parse(s) - Date.now()) < 7 * 86_400_000;

/** Parse keeping every number's source text (UInt64 RNG state does not survive a double). */
const parseExact = (text) => JSON.parse(text, (_k, v, ctx) => (typeof v === 'number' ? numberKey(ctx.source) : v));
const numberKey = (src) => (/^-?\d+$/.test(src) ? src : String(Number(src)));

/**
 * Canonical form of a saved game: wall-clock fields go, UUIDs (random per process) become "<uuid>", object keys sort,
 * and arrays sort by their elements' canonical JSON. Sets and non-String-keyed dictionaries encode in hash order,
 * which Swift seeds per process; the replies (compared in order) cover ordering.
 */
function normalize(value) {
  if (Array.isArray(value)) {
    return value.map(normalize).map((v) => [JSON.stringify(v), v]).sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0)).map((p) => p[1]);
  }
  if (value && typeof value === 'object') {
    const out = {};
    for (const k of Object.keys(value).sort()) out[UUID.test(k) ? '<uuid>' : k] = normalize(value[k]);
    return out;
  }
  if (typeof value === 'string' && UUID.test(value)) return '<uuid>';
  return typeof value === 'string' && isWallClock(value) ? '<now>' : value;
}

class Divergence extends Error {}

/** A crisis's epigraph is picked by its random UUID (Quotations.pick), so it differs between any two processes. */
const EPIGRAPH = /^\s*“[^]*” — /;
const maskEpigraphs = (reply) => ({ ...reply, events: (reply.events ?? []).map((e) => (EPIGRAPH.test(e.text) ? { ...e, text: '<epigraph>' } : e)) });

const TOL = Number(process.env.SOAK_TOLERANCE ?? 0);
let noise = 0;
function tolerantDifference(a, b, path = '') {
  if (typeof a === 'number' && typeof b === 'number' && a !== b && TOL > 0) {
    const r = Math.abs(a - b) / Math.max(Math.abs(a), Math.abs(b));
    if (r <= TOL) { noise = Math.max(noise, r); return null; }
    return `${path}: ${a} != ${b}`;
  }
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    const keys = Array.isArray(a) ? [...Array(Math.max(a.length, b.length)).keys()] : [...new Set([...Object.keys(a), ...Object.keys(b)])].sort();
    for (const k of keys) { const d = tolerantDifference(a[k], b[k], `${path}/${k}`); if (d) return d; }
    return null;
  }
  return firstDifference(a, b, path);
}

async function both(op, payload, where) {
  const n = await nativeCall(op, payload ?? '');
  const w = await otherCall(op, payload);
  if (n !== w) {
    const d = tolerantDifference(maskEpigraphs(JSON.parse(n)), maskEpigraphs(JSON.parse(w)));
    if (d) throw new Divergence(`${where}: reply differs: ${d}`);
  }
  return JSON.parse(w);
}

async function compareSaves(where) {
  const n = await nativeCall(OP.save), w = await otherCall(OP.save);
  if (n === w) return n.length;
  const d = TOL > 0 ? null : firstDifference(normalize(parseExact(n)), normalize(parseExact(w)));
  if (d) throw new Divergence(`${where}: saved game differs: ${d}`);
  return n.length;
}

let totalTurns = 0, totalCalls = 0, maxSave = 0, failed = false;
for (const g of games) {
  const label = `${g.year}:${g.seed}${g.hawk ? ' hawk' : ''} (${g.rules}, ${g.player}, ${g.turnLength})`;
  const t0 = performance.now();
  let turns = 0;
  try {
    let r = await both(OP.newGame, JSON.stringify({ player: g.player, year: g.year, seed: g.seed, rules: g.rules, turnLength: g.turnLength }), `${label} newGame`);
    if (!r.ok) throw new Error(`${label}: newGame failed: ${r.error}`);
    totalCalls++;
    const orders = g.hawk ? HAWK : DOVE;
    for (let t = 0; t < g.turns && !r.state.gameOver; t++) {
      const at = `${label} turn ${r.state.turn}`;
      // The crisis on the desk: its likeliest option (Watch mode's fallback when no advisor recommends one).
      for (let k = 0; k < 6 && r.state.crisis && !r.state.gameOver; k++) {
        const o = r.state.crisis.options;
        const pick = o.reduce((best, x, i) => (x.successChance > o[best].successChance ? i : best), 0);
        r = await both(OP.act, JSON.stringify({ crisisOption: pick }), `${at} crisis`);
        totalCalls++;
        if (!r.ok) break;
      }
      if (r.state?.gameOver) break;
      const live = (r.state?.nations ?? []).filter((n) => !n.destroyed && n.id !== g.player).map((n) => n.id).sort();
      if (live.length) {
        const nuke = g.hawk && t > 0 && t % 40 === 0;
        const action = nuke ? 'Launch Nukes' : orders[t % orders.length];
        const target = live[(t * 7) % live.length];
        r = await both(OP.act, JSON.stringify({ action, target }), `${at} ${action} ${target}`);
        totalCalls++;
      }
      r = await both(OP.endTurn, undefined, `${at} endTurn`);
      totalCalls++;
      if (!r.ok) throw new Error(`${at}: endTurn failed: ${r.error}`);
      maxSave = Math.max(maxSave, await compareSaves(`${at} save`));
      turns++;
    }
    totalTurns += turns;
    const end = r.state?.gameOver ? `game over at turn ${r.state.turn}: ${r.state.gameOverReason}` : `turn ${r.state.turn}`;
    console.log(`PASS soak ${label}: ${turns} turns identical, ${end} (${((performance.now() - t0) / 1000).toFixed(1)} s)`);
  } catch (e) {
    failed = true;
    totalTurns += turns;
    console.log(`FAIL soak ${label} after ${turns} turns\n     ${e instanceof Divergence ? 'first difference' : 'error'}: ${e.message}`);
    if (!(e instanceof Divergence)) console.log(e.stack);
  }
}
if (TOL > 0) console.log(`soak: float noise up to ${noise.toExponential(2)} (relative)`);
console.log(`soak: ${totalTurns} turns, ${totalCalls} bridge calls, saves up to ${(maxSave / 1e6).toFixed(1)} MB`);
native.child.stdin.end();
process.exit(failed ? 1 : 0);

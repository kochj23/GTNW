// play-wasm.mjs: play the golden games in the WebAssembly engine under Node and print them in gtnw-golden's format.
//   node play-wasm.mjs <gtnw.wasm> <repo root> [year:seedhex:turns ...]
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { loadGTNW, RESOURCE_FILES } from '../js/gtnw.mjs';

const [wasmPath, root, ...specs] = process.argv.slice(2);
const resources = Object.fromEntries(Object.entries(RESOURCE_FILES).map(([n, p]) => [n, readFileSync(join(root, p))]));
const gtnw = await loadGTNW(readFileSync(wasmPath), resources, { log: (fd, t) => process.stderr.write(t + '\n') });
const games = (specs.length ? specs : ['1789:6fd:12', '1962:7aa:12', '2025:7e9:12']).map((s) => s.split(':'));
const out = { rngVectors: gtnw.goldenVectors(), games: [] };
for (const [year, seed, turns] of games) {
  const t0 = performance.now();
  out.games.push(gtnw.golden(Number(year), seed, Number(turns)));
  process.stderr.write(`game ${year}: ${(performance.now() - t0).toFixed(0)} ms\n`);
}
process.stdout.write(JSON.stringify(out) + '\n');

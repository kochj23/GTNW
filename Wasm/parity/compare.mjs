// compare.mjs: compare golden games played by GTNWCore (native CLI or WebAssembly) with the fixtures the app
// exported (GTNWTests/GoldenExportTests). Exact: every input and every turn's snapshot, the opening board and the
// RNG vectors. Prints the first difference per game and exits 1 on any.
//
//   node compare.mjs <fixtures dir> <played.json> [label]
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

export function firstDifference(a, b, path = '') {
  if (typeof a !== typeof b || Array.isArray(a) !== Array.isArray(b) || (a === null) !== (b === null)) {
    return `${path || '/'}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`;
  }
  if (a && typeof a === 'object') {
    const keys = Array.isArray(a) ? [...Array(Math.max(a.length, b.length)).keys()] : [...new Set([...Object.keys(a), ...Object.keys(b)])].sort();
    for (const k of keys) {
      const d = firstDifference(a[k], b[k], `${path}/${k}`);
      if (d) return d;
    }
    return null;
  }
  return Object.is(a, b) || a === b ? null : `${path}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`;
}

export function compare(fixturesDir, played) {
  const manifest = JSON.parse(readFileSync(join(fixturesDir, 'manifest.json'), 'utf8'));
  const results = [];
  const v = firstDifference(manifest.rngVectors, played.rngVectors);
  results.push({ name: 'rngVectors', ok: !v, diff: v });
  for (const info of manifest.games) {
    const want = JSON.parse(readFileSync(join(fixturesDir, info.file), 'utf8'));
    const got = played.games.find((g) => g.game.file === info.file);
    if (!got) { results.push({ name: info.file, ok: false, diff: 'not played' }); continue; }
    const d = firstDifference(want, got);
    results.push({ name: info.file, ok: !d, diff: d, turns: got.turns.length });
  }
  return results;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [fixtures, playedPath, label = 'played'] = process.argv.slice(2);
  if (!fixtures || !playedPath) { console.error('usage: node compare.mjs <fixtures dir> <played.json> [label]'); process.exit(2); }
  const results = compare(fixtures, JSON.parse(readFileSync(playedPath, 'utf8')));
  for (const r of results) console.log(`${r.ok ? 'PASS' : 'FAIL'} ${label} ${r.name}${r.turns ? ` (${r.turns} turns)` : ''}${r.ok ? '' : `\n     first difference: ${r.diff}`}`);
  process.exit(results.every((r) => r.ok) ? 0 : 1);
}

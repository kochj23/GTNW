// gtnw.mjs: load the GTNW engine (Wasm/dist/gtnw.wasm, the GTNWWasm reactor) in a browser or Node and drive it
// through its JSON bridge. No dependencies: the engine needs only a sliver of WASI (clock, random, stdout), shimmed
// here; it has no files, no network and no threads.
//
//   const gtnw = await loadGTNW(wasmBytes, { nation_cabinets: bytes, ... });
//   gtnw.newGame({ player: 'USA', year: 1962, seed: '7aa' }) → { ok, events, state }
//   gtnw.act({ action: 'Send Ambassador', target: 'FRA' })   gtnw.act({ crisisOption: 0 })
//   gtnw.endTurn()   gtnw.snapshot()   gtnw.save() → string   gtnw.load(string)
//   gtnw.golden(1962, '7aa', 12) → a game in the golden fixture format

const ENOSYS = 52, EBADF = 8;

/** The WASI imports the Swift runtime and Foundation link against. `log` gets stdout/stderr lines. */
function wasiShim(getMemory, log) {
  const view = () => new DataView(getMemory().buffer);
  const bytes = () => new Uint8Array(getMemory().buffer);
  const decoder = new TextDecoder();
  const nosys = () => ENOSYS;
  return {
    // argv = ["gtnw"]: Foundation's Bundle.main traps without an argv[0].
    args_sizes_get: (argc, size) => { view().setUint32(argc, 1, true); view().setUint32(size, 5, true); return 0; },
    args_get: (argv, buf) => { view().setUint32(argv, buf, true); bytes().set([103, 116, 110, 119, 0], buf); return 0; },
    environ_sizes_get: (count, size) => { view().setUint32(count, 0, true); view().setUint32(size, 0, true); return 0; },
    environ_get: () => 0,
    clock_res_get: (_id, out) => { view().setBigUint64(out, 1000n, true); return 0; },
    clock_time_get: (id, _precision, out) => {
      const ns = id === 0 ? BigInt(Date.now()) * 1000000n : BigInt(Math.round(performance.now() * 1e6));
      view().setBigUint64(out, ns, true);
      return 0;
    },
    random_get: (ptr, len) => {
      // getRandomValues takes at most 64 KiB per call.
      for (let off = 0; off < len; off += 65536) crypto.getRandomValues(bytes().subarray(ptr + off, ptr + Math.min(len, off + 65536)));
      return 0;
    },
    fd_write: (fd, iovs, iovsLen, written) => {
      if (fd !== 1 && fd !== 2) return EBADF;
      let n = 0, text = '';
      for (let i = 0; i < iovsLen; i++) {
        const p = view().getUint32(iovs + i * 8, true), len = view().getUint32(iovs + i * 8 + 4, true);
        text += decoder.decode(bytes().subarray(p, p + len));
        n += len;
      }
      if (text.trim()) log?.(fd, text.replace(/\n$/, ''));
      view().setUint32(written, n, true);
      return 0;
    },
    fd_fdstat_get: (fd, out) => {
      if (fd > 2) return EBADF;
      const v = view();
      v.setUint8(out, 2);                     // character device
      v.setUint16(out + 2, 0, true);
      v.setBigUint64(out + 8, 0n, true);
      v.setBigUint64(out + 16, 0n, true);
      return 0;
    },
    fd_prestat_get: () => EBADF,              // no preopened directories: no file system
    fd_close: () => 0,
    proc_exit: (code) => { throw new Error(`gtnw: exit ${code}`); },
    poll_oneoff: nosys, fd_fdstat_set_flags: nosys, fd_filestat_get: nosys, fd_filestat_set_size: nosys,
    fd_filestat_set_times: nosys, fd_pread: nosys, fd_prestat_dir_name: nosys, fd_read: nosys, fd_readdir: nosys,
    fd_seek: nosys, fd_sync: nosys, fd_tell: nosys, path_create_directory: nosys, path_filestat_get: nosys,
    path_filestat_set_times: nosys, path_link: nosys, path_open: nosys, path_readlink: nosys,
    path_remove_directory: nosys, path_rename: nosys, path_symlink: nosys, path_unlink_file: nosys,
  };
}

const OP = { newGame: 1, act: 2, endTurn: 3, snapshot: 4, save: 5, load: 6, setResource: 7, golden: 8, goldenVectors: 9, query: 10 };

/**
 * Instantiate the engine. `source` is the .wasm as bytes, a WebAssembly.Module, or a fetch Response (streamed).
 * `resources` maps data file names (nation_cabinets, nation_characters, world_countries, base_rates, open_wars) to
 * their bytes; the engine reads nothing else.
 */
export async function loadGTNW(source, resources = {}, { log } = {}) {
  let memory;
  const imports = { wasi_snapshot_preview1: wasiShim(() => memory, log) };
  let instance;
  if (source instanceof WebAssembly.Module) instance = await WebAssembly.instantiate(source, imports);
  else if (typeof Response !== 'undefined' && source instanceof Response) ({ instance } = await WebAssembly.instantiateStreaming(source, imports));
  else ({ instance } = await WebAssembly.instantiate(source, imports));
  const x = instance.exports;
  memory = x.memory;
  x._initialize();

  const encoder = new TextEncoder(), decoder = new TextDecoder();
  function call(op, payload = new Uint8Array()) {
    const ptr = payload.length ? x.gtnw_alloc(payload.length) : 0;
    if (ptr) new Uint8Array(memory.buffer, ptr, payload.length).set(payload);
    try {
      const len = x.gtnw_call(op, ptr, payload.length);
      return decoder.decode(new Uint8Array(memory.buffer, x.gtnw_reply_ptr(), len));
    } finally {
      if (ptr) x.gtnw_free(ptr);
    }
  }
  const json = (op, value) => JSON.parse(call(op, value === undefined ? undefined : encoder.encode(JSON.stringify(value))));

  for (const [name, data] of Object.entries(resources)) {
    const head = encoder.encode(name + '\n');
    const body = data instanceof Uint8Array ? data : new Uint8Array(data);
    const msg = new Uint8Array(head.length + body.length);
    msg.set(head); msg.set(body, head.length);
    call(OP.setResource, msg);
  }

  return {
    newGame: (config = {}) => json(OP.newGame, config),
    act: (order) => json(OP.act, order),
    endTurn: () => json(OP.endTurn),
    snapshot: () => json(OP.snapshot),
    save: () => call(OP.save),
    load: (save) => JSON.parse(call(OP.load, encoder.encode(save))),
    golden: (year, seed, turns) => json(OP.golden, { year, seed, turns }),
    goldenVectors: () => json(OP.goldenVectors),
    query: (q, args = {}) => json(OP.query, { ...args, q }),
    /** One call by op number, with the reply as the engine wrote it (the soak compares replies byte for byte). */
    raw: (op, text) => call(op, text === undefined ? undefined : encoder.encode(text)),
  };
}

/** The data files the engine wants, by name → path relative to the GTNW repo root. */
export const RESOURCE_FILES = {
  nation_cabinets: 'Shared/Resources/nation_cabinets.json',
  nation_characters: 'Shared/Resources/nation_characters.json',
  world_countries: 'Shared/Resources/world_countries.json',
  base_rates: 'Documentation/wars/base_rates.json',
  open_wars: 'Documentation/wars/open_wars.json',
};

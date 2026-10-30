// Runs a wasm32-wasip1 command module on Node's V8 through node:wasi (WASI preview1).
//   node --predictable --single-threaded --single-threaded-gc /opt/wasm/run-node.mjs [--env NAME=VALUE ...] [--random-os] <module.wasm> [args...]
// The module sees argv = [<module.wasm>, args...], an environment holding only the --env pairs (empty by
// default) and /app preopened (always, as `wasmtime run --dir /app::/app` does; lanes whose wasmtime template
// has no --dir simply never open a file). The exit code is propagated.
// random_get is deterministic by default: it returns a fixed xorshift32 byte stream (seed 0x9e3779b9), the same
// in every run. A runtime that seeds itself from it (Go does at startup) otherwise moves the V8 process's
// instruction count by millions of instructions from run to run, and I(n1) and I(n2) draw different seeds.
// --random-os restores node:wasi's own random_get (OS randomness).
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';

const argv = process.argv.slice(2);
const env = {};
let osRandom = false;
for (;;) {
  if (argv[0] === '--env') {
    const pair = argv[1] ?? '';
    const eq = pair.indexOf('=');
    if (eq < 1) {
      process.stderr.write(`run-node.mjs: --env expects NAME=VALUE, got '${pair}'\n`);
      process.exit(2);
    }
    env[pair.slice(0, eq)] = pair.slice(eq + 1);
    argv.splice(0, 2);
  } else if (argv[0] === '--random-os') {
    osRandom = true;
    argv.splice(0, 1);
  } else {
    break;
  }
}
const [file, ...args] = argv;
if (!file) {
  process.stderr.write('usage: run-node.mjs [--env NAME=VALUE ...] [--random-os] <module.wasm> [args...]\n');
  process.exit(2);
}
const wasi = new WASI({
  version: 'preview1',
  args: [file, ...args],
  env,
  preopens: { '/app': '/app' },
  returnOnExit: true,
});
const imports = wasi.getImportObject();
let instance;
if (!osRandom) {
  let s = 0x9e3779b9;
  imports.wasi_snapshot_preview1.random_get = (ptr, len) => {
    const out = new Uint8Array(instance.exports.memory.buffer, ptr, len);
    for (let i = 0; i < len; i++) {
      s ^= s << 13; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
      out[i] = s & 0xff;
    }
    return 0;
  };
}
const module = await WebAssembly.compile(await readFile(file));
instance = await WebAssembly.instantiate(module, imports);
process.exitCode = wasi.start(instance);

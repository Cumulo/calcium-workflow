import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const output = resolve(process.argv[2] ?? "js-out");
let result = null;
const selectors = [];
globalThis.document = {
  querySelector(selector) {
    selectors.push(selector);
    return result;
  },
  // Respo creates its shared canvas context when modules are imported.
  createElement(tag) {
    assert.equal(tag, "canvas");
    return { getContext(kind) { assert.equal(kind, "2d"); return {}; } };
  },
};
const client = await import(pathToFileURL(resolve(output, "app.sync.client.mjs")).href);
const core = await import(pathToFileURL(resolve(output, "calcit.core.mjs")).href);
assert.equal(core.option_$o_none_$q_(client.mount_target), true);
assert.equal(core.option_$o_none_$q_(client.query_mount_target()), true);
result = { nodeType: 1 };
const mounted = client.query_mount_target();
assert.equal(core.option_$o_some_$q_(mounted), true);
assert.equal(core.option_$o_unwrap(mounted), result);
result = undefined;
assert.equal(core.option_$o_none_$q_(client.query_mount_target()), true);
assert.deepEqual(selectors, [".app", ".app", ".app", ".app"]);
console.log("mount boundary: absence, host identity, selector and eager initialization passed");

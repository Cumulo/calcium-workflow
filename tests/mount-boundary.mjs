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
const client = await import(pathToFileURL(resolve(output, "app.client.mjs")).href);
assert.equal(client.mount_target, null);
assert.equal(client.query_mount_target(), null);
result = { nodeType: 1 };
assert.equal(client.query_mount_target(), result);
result = undefined;
assert.equal(client.query_mount_target(), null);
assert.deepEqual(selectors, [".app", ".app", ".app", ".app"]);
console.log("mount boundary: absence, host identity, selector and eager initialization passed");

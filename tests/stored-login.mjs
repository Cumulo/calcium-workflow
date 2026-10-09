import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const output = resolve(process.argv[2] ?? "js-out");
let raw = null;
let readError;
const keys = [];
const storage = {
  length: 0,
  getItem(key) {
    keys.push(key);
    if (readError) throw readError;
    return raw;
  },
  key() { return null; },
  setItem() {},
  removeItem() {},
  clear() {},
};
globalThis.window = { localStorage: storage };
globalThis.document = {
  querySelector() { return null; },
  createElement(tag) {
    assert.equal(tag, "canvas");
    return { getContext(kind) { assert.equal(kind, "2d"); return {}; } };
  },
};
const load = name => import(pathToFileURL(resolve(output, name)).href);
const { stored_login } = await load("app.sync.client.mjs");
const c = await load("calcit.core.mjs");
assert.equal(stored_login().tag.value, "none");
raw = "[] |demo |password";
const present = stored_login();
assert.equal(present.tag.value, "some");
assert.deepEqual(c.to_js_data(present.get(1)), ["demo", "password"]);
raw = "[] | |";
assert.deepEqual(c.to_js_data(stored_login().get(1)), ["", ""]);
raw = "[] |demo 42";
assert.throws(() => stored_login(), /expected string/i);
raw = "{}";
assert.throws(() => stored_login(), /expected list/i);
readError = new Error("storage denied");
assert.throws(() => stored_login(), error => error === readError);
assert.ok(keys.every(key => key === "calcium-storage"));
console.log("stored login: absence, String credentials, empty strings, invalid data and host exception propagation passed");

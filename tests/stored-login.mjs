import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const output = resolve(process.argv[2] ?? "js-out");
let raw = null;
let readError;
let writeError;
const keys = [];
const writes = [];
const storage = {
  length: 0,
  getItem(key) {
    keys.push(key);
    if (readError) throw readError;
    return raw;
  },
  key() { return null; },
  setItem(key, value) {
    if (writeError) throw writeError;
    writes.push([key, value]);
  },
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

const { on_submit } = await load("app.comp.login.mjs");
const dispatched = [];
const submit = on_submit("demo", "password", false);
globalThis.localStorage = storage;
submit(null, op => { dispatched.push(op); });
assert.equal(dispatched.at(-1).tag.value, "user/log-in");
assert.equal(writes[0][0], "calcium-storage");
assert.deepEqual(c.to_js_data(c.parse_cirru_edn(writes[0][1])), ["demo", "password"]);
writeError = new Error("storage quota denied");
assert.throws(() => submit(null, op => { dispatched.push(op); }), error => error === writeError);
assert.equal(dispatched.length, 2, "dispatch still precedes persistence failure");
const denied = new Error("storage getter denied");
Object.defineProperty(globalThis, "localStorage", { configurable: true, get() { throw denied; } });
assert.throws(() => submit(null, () => {}), error => error === denied);
delete globalThis.localStorage;
globalThis.localStorage = undefined;
submit(null, () => {});
assert.equal(writes.length, 1, "absent storage must not write");
delete globalThis.localStorage;
console.log("stored login: original reads, submit roundtrip, dispatch-before-error, getter/quota propagation and absence passed");

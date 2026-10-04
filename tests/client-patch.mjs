import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const output = resolve(process.argv[2] ?? "js-out");
const load = (name) => import(pathToFileURL(resolve(output, name)).href);
// Only module initialization uses these browser capabilities; no connection is started.
globalThis.document = {
  querySelector() { return null; },
  createElement(tag) {
    assert.equal(tag, "canvas");
    return { getContext(kind) { assert.equal(kind, "2d"); return {}; } };
  },
};
const c = await load("calcit.core.mjs");
const { validate_server_patch } = await load("app.client.mjs");
const { change_op } = await load("recollect.schema.mjs");
const { database, session, decode_store, decode_server_message } = await load("app.schema.mjs");
const { twig_container, twig_shared } = await load("app.twig.container.mjs");
const tags = c.init_tags(["assoc", "update", "replace"]);
const op = (tag, ...args) => c._PCT__$o__$o_(change_op, tags[tag], ...args);
const list = (...items) => c.arrayToList(items);
const base = c.parse_cirru_edn("{} (:stable 1)");
const updated = validate_server_patch(base, 9, 9, list(op("assoc", c.init_tags(["stable"]).stable, 2)));
assert.equal(updated.tag.value, "ok");
assert.deepEqual(c.to_js_data(updated.get(1)), { stable: 2 });
const invalid = validate_server_patch(base, 9, 9, list(
  op("assoc", c.init_tags(["temporary"]).temporary, 2),
  op("update", c.init_tags(["missing"]).missing, op("replace", 3)),
));
assert.equal(invalid.tag.value, "err");
assert.equal(invalid.get(1).tag.value, "invalid-patch");
assert.deepEqual(c.to_js_data(base), { stable: 1 });
const mismatch = validate_server_patch(base, 9, 10, list());
assert.equal(mismatch.tag.value, "err");
assert.equal(mismatch.get(1).tag.value, "revision-mismatch");
const store = twig_container(database, session, twig_shared(database, 0));
const unchanged = validate_server_patch(store, 9, 9, list());
assert.equal(unchanged.tag.value, "ok");
assert.ok(c._$n__$e_(store, unchanged.get(1)));
// A nominal Struct identity alone does not prove its nested fields are valid.
const fields = c.init_tags(["count", "session", "id", "user", "some", "unknown", "snapshot"]);
const corruptCount = c._$n_struct_$o_assoc(store, fields.count, "not-a-number");
const rejectedCount = decode_store(corruptCount);
assert.equal(rejectedCount.tag.value, "err");
assert.match(rejectedCount.get(1), /\$\.count/);
const badSession = c._$n_struct_$o_assoc(c.get(store, fields.session).get(1), fields.id, c._PCT_some("bad-id"));
const corruptSession = c._$n_struct_$o_assoc(store, fields.session, badSession);
const rejectedSession = decode_store(corruptSession);
assert.equal(rejectedSession.tag.value, "err");
assert.match(rejectedSession.get(1), /\$\.session\.id/);
const rejectedSnapshot = decode_server_message(c._$o__$o_(fields.snapshot, 7, corruptSession));
assert.equal(rejectedSnapshot.tag.value, "err");
assert.match(rejectedSnapshot.get(1).get(1), /\$\.session\.id/);
const invalidOption = c._$n_enum_$o_assoc(c._PCT_some("payload"), 0, fields.unknown);
assert.equal(decode_store(c._$n_struct_$o_assoc(store, fields.user, invalidOption)).tag.value, "err");
assert.equal(decode_store(c._$n_struct_$o_assoc(store, fields.user, "bad-option")).tag.value, "err");
assert.ok(c._$n__$e_(store, decode_store(store).get(1)));
console.log("client patch: valid update, atomic rejection, revision mismatch and nominal store passed");
console.log("store decoder: corrupt scalar, nested Option and snapshot rejected before publication");

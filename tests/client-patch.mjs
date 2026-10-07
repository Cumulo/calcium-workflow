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
const client = await load("app.sync.client.mjs");
const { validate_server_patch } = client;
const ws = await load("ws-edn.client.mjs");
const { change_op } = await load("recollect.schema.mjs");
const { database, session, decode_store, decode_server_message, decode_client_message } = await load("app.schema.mjs");
const { twig_container, twig_shared } = await load("app.twig.container.mjs");
const tags = c.init_tags(["assoc", "update", "replace"]);
const op = (tag, ...args) => c._PCT__$o__$o_(change_op, tags[tag], ...args);
const list = (...items) => c.arrayToList(items);
const patchTag = c.init_tags(["patch"]).patch;
const vecDropTag = c.init_tags(["vec-drop"])["vec-drop"];
const corruptDrop = c._$n_enum_$o_assoc(c._PCT__$o__$o_(change_op, vecDropTag, 1), 1, "bad-count");
for (const envelope of [
  42,
  c._$o__$o_(patchTag, 1, 2, list(42)),
  c._$o__$o_(patchTag, 1, 2, list(corruptDrop)),
  c._$o__$o_(patchTag, 1, 2, list(op("update", "field", corruptDrop))),
]) {
  assert.equal(decode_server_message(envelope).tag.value, "err");
}
const validEnvelope = decode_server_message(c._$o__$o_(patchTag, 1, 2, list(op("replace", 3))));
assert.equal(validEnvelope.tag.value, "ok");
assert.ok(c._$n__$e_(validEnvelope.get(1).get(3), list(op("replace", 3))));
for (const value of [42, c.parse_cirru_edn("{}"), list(patchTag), c.parse_cirru_edn(":: :dispatch 42")]) {
  assert.equal(decode_client_message(value).tag.value, "err");
}
const base = twig_container(database, session, twig_shared(database, 0));
const keys = c.init_tags(["count", "color", "missing", "session", "id"]);
const updated = validate_server_patch(base, 9, 9, list(op("assoc", keys.count, 2)), decode_store);
assert.equal(updated.tag.value, "ok");
assert.equal(c.get(updated.get(1), keys.count).get(1), 2);
const invalid = validate_server_patch(base, 9, 9, list(
  op("assoc", keys.count, 2),
  op("update", keys.missing, op("replace", 3)),
), decode_store);
assert.equal(invalid.tag.value, "err");
assert.equal(invalid.get(1).tag.value, "invalid-patch");
assert.notEqual(c.get(base, keys.count).get(1), 2);
const mismatch = validate_server_patch(base, 9, 10, list(), decode_store);
assert.equal(mismatch.tag.value, "err");
assert.equal(mismatch.get(1).tag.value, "revision-mismatch");
const store = twig_container(database, session, twig_shared(database, 0));
const unchanged = validate_server_patch(store, 9, 9, list(), decode_store);
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

// Exercise actual state publication and wire acknowledgement, with no network.
const sent = [];
const socket = { readyState: 1, send(data) { sent.push(data); }, close() {} };
const connection = ws.create_client_with_$x_("ws://test.invalid", c.parse_cirru_edn("{}"), () => socket);
socket.onopen({});
c.reset_$x_(ws._$s_global_client, c._PCT_some(connection));
const consoleError = console.error;
const consoleWarn = console.warn;
console.error = () => {};
console.warn = () => {};
try {
  const ready = c._PCT__$o__$o_(client.ClientState, c.init_tags(["ready"]).ready, store);
  c.reset_$x_(client._$s_store, ready);
  c.reset_$x_(client._$s_sync_revision, 9);
  for (const changes of [
    list(op("replace", "different-type")),
    list(op("assoc", keys.count, 2), op("assoc", keys.color, 42)),
    list(op("update", keys.session, op("assoc", keys.id, c._PCT_some("bad-id")))),
  ]) {
    sent.length = 0;
    assert.equal(client.apply_server_patch_$x_(9, 10, changes), undefined);
    assert.strictEqual(c.deref(client._$s_store), ready);
    assert.equal(c.deref(client._$s_sync_revision), 9);
    assert.equal(sent.length, 1);
    const request = decode_client_message(c.parse_cirru_edn(sent[0]));
    assert.equal(request.tag.value, "ok");
    assert.equal(request.get(1).tag.value, "sync/resume");
    assert.equal(request.get(1).get(1), 9);
  }
  sent.length = 0;
  client.apply_server_patch_$x_(9, 10, list(op("assoc", keys.count, 2)));
  assert.equal(c.get(c.deref(client._$s_store).get(1), keys.count).get(1), 2);
  assert.equal(c.deref(client._$s_sync_revision), 10);
  assert.equal(sent.length, 1);
  const ack = decode_client_message(c.parse_cirru_edn(sent[0]));
  assert.equal(ack.tag.value, "ok");
  assert.equal(ack.get(1).tag.value, "sync/ack");
  assert.equal(ack.get(1).get(1), 10);
  const published = c.deref(client._$s_store);
  sent.length = 0;
  client.apply_server_patch_$x_(9, 11, list(op("assoc", keys.count, 3)));
  assert.strictEqual(c.deref(client._$s_store), published);
  assert.equal(c.deref(client._$s_sync_revision), 10);
  assert.equal(sent.length, 1);
  const resume = decode_client_message(c.parse_cirru_edn(sent[0]));
  assert.equal(resume.tag.value, "ok");
  assert.equal(resume.get(1).tag.value, "sync/resume");
  assert.equal(resume.get(1).get(1), 10);
} finally {
  console.error = consoleError;
  console.warn = consoleWarn;
  ws.client_close_$x_(connection);
  c.reset_$x_(ws._$s_global_client, c._PCT_none());
}
console.log("client patch: valid update, atomic rejection, revision mismatch and nominal store passed");
console.log("store decoder: corrupt scalar, nested Option and snapshot rejected before publication");
console.log("patch publication: invalid result preserves state/revision and requests resume; valid result publishes and acknowledges");

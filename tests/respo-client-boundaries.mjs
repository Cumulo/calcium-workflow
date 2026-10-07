import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const output = resolve(process.argv[2] ?? "js-out");
const load = name => import(pathToFileURL(resolve(output, name)).href);
const listeners = new Map();
const intervals = new Map();
const timeouts = new Map();
let timerId = 0;
globalThis.document = {
  visibilityState: "visible",
  querySelector() { return null; },
  createElement(tag) {
    assert.equal(tag, "canvas");
    return { getContext(kind) { assert.equal(kind, "2d"); return {}; } };
  },
};
Object.defineProperty(globalThis, "navigator", { configurable: true, value: { onLine: true } });
globalThis.window = {
  addEventListener(name, callback) {
    if (!listeners.has(name)) listeners.set(name, new Set());
    listeners.get(name).add(callback);
  },
  removeEventListener(name, callback) {
    listeners.get(name)?.delete(callback);
    if (listeners.get(name)?.size === 0) listeners.delete(name);
  },
};
globalThis.setInterval = (callback, ms) => { const id = ++timerId; intervals.set(id, { callback, ms }); return id; };
globalThis.clearInterval = id => intervals.delete(id);
globalThis.setTimeout = (callback, ms) => { const id = ++timerId; timeouts.set(id, { callback, ms }); return id; };
globalThis.clearTimeout = id => timeouts.delete(id);

const c = await load("calcit.core.mjs");
const client = await load("app.client.mjs");
const schema = await load("app.schema.mjs");
const ws = await load("ws-edn.client.mjs");
const { wrap_dispatch } = await load("respo.controller.client.mjs");
const { comp_container, comp_offline } = await load("app.comp.container.mjs");
const { comp_profile } = await load("app.comp.profile.mjs");
const { twig_container, twig_shared } = await load("app.twig.container.mjs");
const { twig_user } = await load("app.twig.user.mjs");
const { make_string } = await load("respo.render.html.mjs");

const wrapped = wrap_dispatch(c.atom(client.dispatch_from_respo_$x_));
const payload = c.parse_cirru_edn("{} (:value |kept)");
assert.equal(wrapped(c.parse_cirru_edn("[] :field"), payload), undefined);
assert.deepEqual(c.to_js_data(c.deref(client._$s_states)).states.field.data, { value: "kept" });
assert.equal(wrapped(c.parse_cirru_edn("[] :mixed |id 7"), payload), undefined);
assert.deepEqual(c.to_js_data(c.deref(client._$s_states)).states.mixed.id["7"].data, { value: "kept" });
const priorStates = c.deref(client._$s_states);
for (const raw of [42, c.parse_cirru_edn("{}"), c.parse_cirru_edn(":: :states 42 $ {}")]) {
  assert.throws(() => client.dispatch_from_respo_$x_(raw), /Invalid-UI-operation/);
  assert.strictEqual(c.deref(client._$s_states), priorStates);
}
assert.throws(() => client.dispatch_from_respo_$x_(c.parse_cirru_edn(":: :unknown")), /Invalid-UI-operation/);

const sent = [];
const socket = { readyState: 1, send(data) { sent.push(data); }, close() {} };
const connection = ws.create_client_with_$x_("ws://test.invalid", c.parse_cirru_edn("{}"), () => socket);
socket.onopen({});
c.reset_$x_(ws._$s_global_client, c._PCT_some(connection));
assert.equal(wrapped(c.init_tags(["user/log-out"])["user/log-out"], null), undefined);
const message = schema.decode_client_message(c.parse_cirru_edn(sent.at(-1)));
assert.equal(message.tag.value, "ok");
assert.equal(message.get(1).tag.value, "dispatch");
assert.equal(message.get(1).get(1).tag.value, "user/log-out");

c.reset_$x_(client._$s_connected_$q_, true);
client.install_activity_lifecycle_$x_();
client.install_activity_lifecycle_$x_();
assert.equal(listeners.size, 4);
assert.ok([...listeners.values()].every(callbacks => callbacks.size === 1));
assert.equal(intervals.size, 1);
const heartbeat = [...intervals.values()][0];
assert.equal(heartbeat.ms, 30000);
assert.equal(heartbeat.callback(), undefined);
document.visibilityState = "hidden";
for (const callback of listeners.get("visibilitychange")) assert.equal(callback({}), undefined);
document.visibilityState = "visible";
// DOM ignores the listener's return; this branch also schedules the library's touch cooldown.
for (const callback of listeners.get("visibilitychange")) callback({});
client.cleanup_activity_lifecycle_$x_();
assert.equal(listeners.size, 0);
assert.equal(intervals.size, 0);
assert.equal(timeouts.size, 0);
ws.client_close_$x_(connection);
c.reset_$x_(ws._$s_global_client, c._PCT_none());

for (const [tag, text] of [["loading", "Loading..."], ["offline", "No connection..."]]) {
  const html = make_string(comp_offline(c.parse_cirru_edn(`:: :${tag}`)));
  assert.ok(html.includes(text));
  assert.ok(html.includes('data-comp="comp-offline"'));
}
const store = twig_container(schema.database, schema.session, twig_shared(schema.database, 0));
const resourceModule = await load("app.resource.mjs");
const emptyPartitions = c.parse_cirru_edn("{}");
const html = make_string(comp_container(c.parse_cirru_edn("{} (:cursor ([]))"), store, emptyPartitions, resourceModule.empty_resources));
for (const text of ["Username", "Password", "Sign up", "Log in"]) assert.ok(html.includes(text), text);
assert.ok(html.includes('data-comp="comp-login"'));

const profileResult = schema.decode_database(c.parse_cirru_edn(
  "{} (:sessions ({})) (:users ({} (|u1 $ {} (:id |u1) (:name |Ada) (:password |hash))))",
));
assert.equal(profileResult.tag.value, "ok");
const profileUser = twig_user(profileResult.get(1).get("users").get("u1"));
const renderMembers = source => make_string(comp_profile(profileUser, c.parse_cirru_edn(source)));
const presentMember = renderMembers("{} (7 $ %:: 'Option :some |Grace)");
assert.ok(presentMember.includes("Grace"));
assert.ok(!presentMember.includes("Option"));
const absentMember = renderMembers("{} (7 $ %:: 'Option :none)");
assert.ok(absentMember.includes("Members:"));
assert.ok(!absentMember.includes("Option"));
assert.ok(renderMembers("{} (7 |Lin)").includes("Lin"));
assert.ok(!renderMembers("{} (7 nil)").includes("nil"));
for (const source of ["{} (7 42)", "{} (7 $ %:: 'Option :some 42)"]) {
  assert.throws(() => renderMembers(source));
}
const { comp_board, comp_history, comp_settings } = await load("app.comp.kanban.mjs");
const { view_fixture } = await load("app.workload.kanban.mjs");
const fixture = view_fixture();
const [boardView, missingView, detailResources, userView, emptyResources] = [0, 1, 2, 3, 4].map(index => fixture.get(index));
const viewStates = c.parse_cirru_edn("{} (:cursor ([]))");
const boardHtml = make_string(comp_board(viewStates, boardView, detailResources, false));
for (const text of ["Roadmap", "Todo", "Doing", "Done", "Ship-partitions", "Cold-text", "cold rev 0 / hot rev 0"]) {
  assert.ok(boardHtml.includes(text), `board view: ${text}`);
}
assert.ok(make_string(comp_board(viewStates, missingView, emptyResources, false)).includes("Board not found."));
assert.ok(make_string(comp_history(emptyResources, userView)).includes(">Load<"));
assert.ok(make_string(comp_settings(userView)).includes("Compact cards: off"));
console.log("Respo client: legacy cursor/Tag dispatch, decoder rejection, lifecycle replacement/cleanup, three SSR views, Kanban board/history/settings SSR and member Option rendering passed without a network connection");

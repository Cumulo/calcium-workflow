// End-to-end smoke against a running native server:
//   port=5099 calcit calcit.cirru --entry server
//   yarn node tests/kanban-e2e.mjs ws://127.0.0.1:5099
// Two clients sign up, open the same board and exchange hot partition
// patches, cold card details and personal history over the real protocol.
import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const url = process.argv[2] ?? "ws://127.0.0.1:5099";
const c = await import(pathToFileURL(resolve("js-out", "calcit.core.mjs")).href);
const tag = (value) => value.tag.value;
const suffix = Date.now().toString(36);

function client(name) {
  const socket = new WebSocket(url);
  const inbox = [];
  const waiters = [];
  const state = { name, socket, inbox, partitions: new Map(), replies: new Map() };
  socket.onmessage = ({ data }) => {
    const message = c.parse_cirru_edn(data);
    const kind = tag(message);
    if (kind === "snapshot" || kind === "patch") {
      const revision = kind === "snapshot" ? message.get(1) : message.get(2);
      send(state, `%:: 'ClientMessage 'sync/ack ${revision}`);
    } else if (kind === "part/snapshot" || kind === "part/patch") {
      const key = c.format_cirru_edn(message.get(1)).trim();
      const epoch = message.get(2);
      let revision;
      if (kind === "part/snapshot") {
        revision = message.get(3);
      } else {
        const deltas = message.get(3);
        revision = deltas.get(deltas.len() - 1).get(c.init_tags(["revision"]).revision);
        const known = state.partitions.get(key);
        assert.ok(known, `${name}: patch before snapshot for ${key}`);
        assert.equal(known.epoch, epoch, `${name}: epoch changed without snapshot`);
        assert.equal(deltas.get(0).get(c.init_tags(["base"]).base), known.revision, `${name}: base mismatch`);
      }
      state.partitions.set(key, { epoch, revision, last: data });
      send(state, `%:: 'ClientMessage 'part/ack (${key}) ${epoch} ${revision}`);
    } else if (kind === "part/drop") {
      state.partitions.delete(c.format_cirru_edn(message.get(1)).trim());
    } else if (kind === "query/reply") {
      state.replies.set(message.get(1), data);
    }
    inbox.push({ kind, data });
    for (const waiter of waiters.splice(0)) waiter();
  };
  state.opened = new Promise((done) => (socket.onopen = done));
  state.waitFor = (predicate, label, timeout = 3000) =>
    new Promise((done, fail) => {
      const started = Date.now();
      const check = () => {
        const found = predicate(state);
        if (found) return done(found);
        if (Date.now() - started > timeout) return fail(new Error(`${name}: timed out waiting for ${label}`));
        waiters.push(check);
        setTimeout(check, 50);
      };
      check();
    });
  return state;
}

function send(state, text) {
  state.socket.send(text);
}

const dispatch = (state, op) => send(state, `%:: 'ClientMessage 'dispatch ${op}`);
const kanban = (state, op) => dispatch(state, `$ %:: 'Op 'kanban $ %:: 'KanbanOp ${op}`);
const route = (state, name, target) =>
  dispatch(state, `$ %:: 'Op 'router/change $ {} (:name :${name}) (:target $ %:: 'Option ${target ? `:some |${target}` : ":none"})`);
const partition = (state, key) => state.partitions.get(key);
const lastData = (state, key) => partition(state, key)?.last ?? "";

const ann = client("ann");
const bob = client("bob");
await Promise.all([ann.opened, bob.opened]);
for (const [state, user] of [[ann, `ann-${suffix}`], [bob, `bob-${suffix}`]]) {
  send(state, "%:: 'ClientMessage 'sync/active 0");
  dispatch(state, `$ %:: 'Op 'user/sign-up |${user} |pw`);
}
await ann.waitFor((s) => partition(s, ":: 'lobby"), "lobby snapshot");
await ann.waitFor((s) => [...s.partitions.keys()].some((k) => k.includes("'user")), "user snapshot");

kanban(ann, `'board/create |Plan-${suffix}`);
const boardId = await ann.waitFor((s) => {
  const match = lastData(s, ":: 'lobby").match(new RegExp(`\\(:id \\|([^ )]+)\\) \\(:title \\|Plan-${suffix}\\)`));
  return match?.[1];
}, "board id in lobby");
const boardKey = `:: 'board |${boardId}`;
route(ann, "board", boardId);
route(bob, "board", boardId);
await ann.waitFor((s) => partition(s, boardKey), "ann board snapshot");
await bob.waitFor((s) => partition(s, boardKey), "bob board snapshot");

const bobBefore = bob.inbox.length;
kanban(ann, `'card/add |${boardId} |${boardId}-todo |Ship`);
await ann.waitFor((s) => partition(s, boardKey)?.revision === 2, "ann board rev 2");
await bob.waitFor((s) => partition(s, boardKey)?.revision === 2, "bob board rev 2");
assert.equal(lastData(ann, boardKey), lastData(bob, boardKey), "subscribers share one encoded board patch");
assert.ok(lastData(bob, boardKey).includes("part/patch"), "board update arrives as a patch, not a snapshot");
assert.ok(!bob.inbox.slice(bobBefore).some((m) => m.kind === "part/snapshot"), "no resnapshot for an ordinary update");
const cardId = lastData(ann, boardKey).match(/\(:id \|([^ )]+)\) \(:rank/)?.[1];
assert.ok(cardId, "card id in board patch");

kanban(ann, `'card/edit-detail |${boardId} |${cardId} "|Write it down"`);
await bob.waitFor((s) => partition(s, boardKey)?.revision === 3, "detail-rev bump on board");
assert.ok(!lastData(bob, boardKey).includes("Write it down"), "cold description never enters the hot board patch");
send(bob, `%:: 'ClientMessage 'query |d1 $ %:: 'Query 'card-detail |${boardId} |${cardId}`);
const detail = await bob.waitFor((s) => s.replies.get("d1"), "card detail reply");
assert.ok(detail.includes("Write it down") && detail.includes("(:rev 1)"), "versioned cold detail");

send(ann, "%:: 'ClientMessage 'query |h1 $ %:: 'Query 'history (%:: 'Option :none) 2");
const history = await ann.waitFor((s) => s.replies.get("h1"), "history reply");
assert.ok(history.includes("edited description") && history.includes("(:history-rev 3)"), "history page newest first");
assert.ok(history.includes(":next-cursor $ %:: 'Option 'some 1"), "older history has a cursor");
send(bob, "%:: 'ClientMessage 'query |h2 $ %:: 'Query 'history (%:: 'Option :none) 5");
const bobHistory = await bob.waitFor((s) => s.replies.get("h2"), "bob history reply");
assert.ok(bobHistory.includes("(:history-rev 0)"), "history is private to the session user");

dispatch(bob, "$ %:: 'Op 'user/log-out");
await bob.waitFor((s) => s.partitions.size === 0, "logout drops every partition");
send(bob, "%:: 'ClientMessage 'query |h3 $ %:: 'Query 'history (%:: 'Option :none) 5");
assert.ok((await bob.waitFor((s) => s.replies.get("h3"), "denied reply")).includes("denied"), "anonymous cold reads are denied");

ann.socket.close();
bob.socket.close();
console.log("kanban e2e: shared board patch, cold detail/history callbacks, private history and logout drop passed");

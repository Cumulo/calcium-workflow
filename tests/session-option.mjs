import assert from "node:assert/strict";
import { decode_database } from "../js-out/app.schema.mjs";
import { twig_container, twig_shared } from "../js-out/app.twig.container.mjs";
import { twig_user } from "../js-out/app.twig.user.mjs";
import { parse_cirru_edn as parse, format_cirru_edn as format, to_js_data as js } from "../js-out/calcit.core.mjs";

const decodedValue = (result, label) => {
  if (result.tag.value !== "ok") throw new Error(`Invalid ${label}`);
  return result.get(1);
};
const project = source => {
  const db = decodedValue(
    decode_database(parse(`{} (:sessions ({} (0 $ ${source}))) (:users ({}))`)),
    "session",
  );
  const session = db.get("sessions").get(0);
  return twig_container(db, session, twig_shared(db, 0));
};
const missing = project("{} (:id 0)");
const explicit = project("{} (:id 0) (:nickname nil) (:user-id nil)");
assert.deepEqual(js(missing), js(explicit));
assert.deepEqual(js(missing).session.id, ["some", 0]);
for (const key of ["nickname", "user-id"]) {
  assert.deepEqual(js(missing).session[key], ["none"]);
}
const present = project("{} (:id 0) (:nickname |) (:user-id nil)");
assert.deepEqual(js(present).session.id, ["some", 0]);
assert.deepEqual(js(present).session.nickname, ["some", ""]);
for (const value of [missing, present]) {
  assert.deepEqual(js(parse(format(value))), js(value));
}
for (const source of ["{} (:id |bad)", "{} (:id 0) (:nickname 42)", "{} (:id 0) (:user-id 42)"]) {
  assert.throws(() => project(source), /Invalid session/);
}
const user = source => {
  const db = decodedValue(
    decode_database(parse(`{} (:sessions ({})) (:users ({} (|u1 $ ${source})))`)),
    "user",
  );
  return twig_user(db.get("users").get("u1"));
};
assert.deepEqual(js(user("{} (:id |u1) (:name |demo) (:password |hash)")).nickname, ["none"]);
const named = user("{} (:id |u1) (:name |demo) (:nickname |nick) (:avatar |image) (:password |hash)");
assert.deepEqual(js(named).nickname, ["some", "nick"]);
assert.deepEqual(js(named).avatar, ["some", "image"]);
assert.deepEqual(js(parse(format(named))), js(named));

const persistedDb = decodedValue(
  decode_database(parse("{} (:sessions ({})) (:users ({} (|u1 $ {} (:id |u1) (:name |demo) (:nickname |) (:avatar nil) (:password |hash))))")),
  "persisted database fixture",
);
const restoredDb = decodedValue(decode_database(parse(format(persistedDb))), "nominal persisted database");
assert.deepEqual(js(restoredDb), js(persistedDb));

const invalidNominalOption = "%{} 'Db (:sessions ({})) (:users ({} (|u1 $ %{} 'User (:id |u1) (:name |demo) (:nickname (%:: 'Option :some 42)) (:avatar (%:: 'Option :none)) (:password |hash))))";
assert.equal(decode_database(parse(invalidNominalOption)).tag.value, "err");
for (const source of ["{} (:id |u1) (:name |demo) (:nickname 42) (:password |hash)", "{} (:id |u1) (:name |demo) (:avatar false) (:password |hash)"]) {
  assert.throws(() => user(source), /Invalid user/);
}
console.log("Session/User Option JS: absent/present, nominal persistence, invalid types and EDN roundtrips passed");

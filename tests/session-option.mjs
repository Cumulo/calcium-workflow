import assert from "node:assert/strict";
import { twig_container, twig_shared } from "../js-out/app.twig.container.mjs";
import { twig_user } from "../js-out/app.twig.user.mjs";
import { parse_cirru_edn as parse, format_cirru_edn as format, to_js_data as js } from "../js-out/calcit.core.mjs";

const records = parse("[]");
const db = parse("{} (:sessions ({})) (:users ({}))");
const shared = twig_shared(db, records);
const project = source => twig_container(db, parse(source), records, shared);
const missing = project("{}");
const explicit = project("{} (:id nil) (:nickname nil) (:user-id nil)");
assert.deepEqual(js(missing), js(explicit));
for (const key of ["id", "nickname", "user-id"]) {
  assert.deepEqual(js(missing).session[key], ["none"]);
}
const present = project("{} (:id 0) (:nickname |)");
assert.deepEqual(js(present).session.id, ["some", 0]);
assert.deepEqual(js(present).session.nickname, ["some", ""]);
for (const value of [missing, present]) {
  assert.deepEqual(js(parse(format(value))), js(value));
}
for (const source of ["{} (:id |bad)", "{} (:nickname 42)", "{} (:user-id 42)"]) {
  assert.throws(() => project(source), /Invalid session/);
}
const user = source => twig_user(parse(source));
assert.deepEqual(js(user("{} (:id |u1) (:name |demo)")).nickname, ["none"]);
const named = user("{} (:id |u1) (:name |demo) (:nickname |nick) (:avatar |image)");
assert.deepEqual(js(named).nickname, ["some", "nick"]);
assert.deepEqual(js(named).avatar, ["some", "image"]);
assert.deepEqual(js(parse(format(named))), js(named));
for (const source of ["{} (:id |u1) (:name |demo) (:nickname 42)", "{} (:id |u1) (:name |demo) (:avatar false)"]) {
  assert.throws(() => user(source), /Invalid user/);
}
console.log("Session/User Option JS: absent/present, zero/empty, invalid types and EDN roundtrips passed");

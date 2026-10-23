// Template/business boundary check for the Calcit snapshot.
//
//   yarn node tests/template-boundary.mjs [--list]
//
// Layers (by namespace prefix):
//   template  app.sync.*            runtime copied unchanged between projects
//   wiring    app.schema, app.hooks*, app.updater, app.client, app.server
//                                   the only places that name the current feature
//   base      app.twig.*, app.updater.*, app.comp.* (minus app.comp.container)
//                                   account/session scaffold most apps keep
//   feature   app.feature.*         replaceable business code
//
// Rules: template code (including attached tests and imports) never names
// app.feature.* or an entry namespace, and reaches business code only through
// app.hooks*. Feature code never depends on the wiring hooks or entries.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const snapshot = fileURLToPath(new URL("../calcit.cirru", import.meta.url));
const run = (...args) => execFileSync(process.env.CALCIT_BIN ?? "calcit", [snapshot, ...args], {
  encoding: "utf8", maxBuffer: 8 * 1024 * 1024,
});
const query = (...args) => JSON.parse(run("query", ...args, "--format", "json")).data;
const files = new Map();
for (const ns of query("ns").namespaces) {
  const namespace = query("ns", ns);
  const listing = run("query", "defs", ns);
  const definitions = listing.split("\n").map(line => line.match(/^  (\S+)(?:\s|$)/)?.[1]).filter(Boolean);
  assert.equal(definitions.length, namespace.definition_count, `incomplete definition listing: ${ns}`);
  files.set(ns, JSON.stringify([namespace.ns_code, ...definitions.map(name => query("def", `${ns}/${name}`))]));
}

const layerOf = (ns) => {
  if (ns.startsWith("app.sync.")) return "template";
  if (ns.startsWith("app.feature.")) return "feature";
  if (["app.schema", "app.updater", "app.client", "app.server", "app.comp.container"].includes(ns) || ns.startsWith("app.hooks.")) return "wiring";
  return "base";
};

const violations = [];
const mentions = (body, pattern) => [...body.matchAll(pattern)].map((match) => match[0]);
for (const [ns, body] of files) {
  const layer = layerOf(ns);
  if (layer === "template") {
    for (const hit of mentions(body, /app\.feature\.[\w.\-]*/g)) violations.push(`${ns} (template) names ${hit}`);
    for (const hit of mentions(body, /\bapp\.(client|server)(?![\w.\-])(\/[^\s)]+)?/g)) violations.push(`${ns} (template) names entry ${hit.trim()}`);
  }
  if (layer === "feature") {
    for (const hit of mentions(body, /\bapp\.hooks(\.[\w-]+)?\b/g)) violations.push(`${ns} (feature) depends on wiring ${hit}`);
    for (const hit of mentions(body, /\bapp\.(client|server)(?![\w.\-])(\/[^\s)]+)?/g)) violations.push(`${ns} (feature) names entry ${hit.trim()}`);
  }
}

if (process.argv.includes("--list")) {
  const byLayer = {};
  for (const ns of [...files.keys()].sort()) (byLayer[layerOf(ns)] ??= []).push(ns);
  for (const [layer, list] of Object.entries(byLayer)) console.log(`${layer.padEnd(9)} ${list.join(" ")}`);
}

assert.ok(files.size > 0, "no namespaces found in calcit.cirru");
assert.ok([...files.keys()].some((ns) => layerOf(ns) === "template"), "no app.sync.* namespaces found");
assert.deepEqual([...new Set(violations)], [], "template boundary violations");
console.log(`template boundary: ${files.size} namespaces checked, app.sync.* reaches business code only through app.hooks*`);

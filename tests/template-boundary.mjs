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
import { readFileSync } from "node:fs";

const snapshot = readFileSync(new URL("../calcit.cirru", import.meta.url), "utf8");
const parts = snapshot.split(/\n    '(app\.[\w.\-$]+) \$ %\{\} 'FileEntry/);
const files = new Map();
for (let index = 1; index < parts.length; index += 2) files.set(parts[index], parts[index + 1]);

const layerOf = (ns) => {
  if (ns.startsWith("app.sync.")) return "template";
  if (ns.startsWith("app.feature.")) return "feature";
  if (["app.schema", "app.hooks", "app.updater", "app.client", "app.server", "app.comp.container"].includes(ns) || ns.startsWith("app.hooks.")) return "wiring";
  return "base";
};

const violations = [];
const mentions = (body, pattern) => [...body.matchAll(pattern)].map((match) => match[0]);
for (const [ns, body] of files) {
  const layer = layerOf(ns);
  if (layer === "template") {
    for (const hit of mentions(body, /app\.feature\.[\w.\-]*/g)) violations.push(`${ns} (template) names ${hit}`);
    for (const hit of mentions(body, /\bapp\.(client|server)(\/[^\s)]+|\s+:)/g)) violations.push(`${ns} (template) names entry ${hit.trim()}`);
  }
  if (layer === "feature") {
    for (const hit of mentions(body, /\bapp\.hooks(\.[\w-]+)?\b/g)) violations.push(`${ns} (feature) depends on wiring ${hit}`);
    for (const hit of mentions(body, /\bapp\.(client|server)(\/[^\s)]+|\s+:)/g)) violations.push(`${ns} (feature) names entry ${hit.trim()}`);
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

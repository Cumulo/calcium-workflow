import assert from "node:assert/strict";
import { resolve } from "node:path";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

const entry = resolve(process.argv[2] ?? "js-out", "app.client.mjs");
const parse = createRequire(entry)("url-parse");
globalThis.document = {
  querySelector() { return null; },
  createElement(tag) {
    assert.equal(tag, "canvas");
    return { getContext(kind) { assert.equal(kind, "2d"); return {}; } };
  },
};
globalThis.location = { href: "https://example.com/", hostname: "example.com" };
const { connection_url } = await import(pathToFileURL(entry).href);
const cases = [
  ["", "ws://example.com:5021"],
  ["?host=localhost&port=9000", "ws://localhost:9000"],
  ["?host=&port=", "ws://:"],
  ["?host=first&host=second", "ws://first:5021"],
  ["?host=a+b&port=0", "ws://a b:0"],
  ["?host=%E4%B8%AD%E6%96%87&port=8000", "ws://中文:8000"],
  ["?host=%ZZ&port=%ZZ", "ws://example.com:5021"],
];
for (const [query, expected] of cases) {
  location.href = `https://example.com/path${query}`;
  const legacy = parse(location.href, true).query;
  const oldUrl = `ws://${legacy.host ?? location.hostname}:${legacy.port ?? 5021}`;
  assert.equal(oldUrl, expected);
  assert.equal(connection_url(), oldUrl);
}
console.log(`connection URL: ${cases.length} legacy query cases passed without opening a socket`);

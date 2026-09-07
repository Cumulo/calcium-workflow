import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import process from "node:process";
import { performance } from "node:perf_hooks";

import * as calcit from "../js-out/calcit.core.mjs";
import { diff_twig } from "../js-out/recollect.diff.mjs";
import { patch_twig, try_patch_twig } from "../js-out/recollect.patch.mjs";
import {
  apply_domain_op,
  make_workload_input,
  project_state,
} from "../js-out/app.workload.diff-patch.mjs";

const args = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  args.set(process.argv[index], process.argv[index + 1] ?? true);
}

const mode = args.get("--mode") ?? "smoke";
assert.ok(mode === "smoke" || mode === "full", `unknown mode: ${mode}`);
const seed = Number(args.get("--seed") ?? 794);
const repetitions = Number(args.get("--repetitions") ?? (mode === "full" ? 30 : 2));
const warmups = Number(args.get("--warmups") ?? (mode === "full" ? 5 : 1));
const sizes = mode === "full" ? [1_000, 10_000] : [100];
const tags = calcit.init_tags(["id", "key"]);
const diffOptions = calcit._$n__$M_(tags.key, tags.id);
const sha256 = (value) => crypto.createHash("sha256").update(value).digest("hex");
const elapsed = (started) => (performance.now() - started) * 1_000;
const equal = (left, right) => calcit._$n__$e_(left, right);

function field(struct, name) {
  const index = struct.fields.findIndex((item) => item.value === name);
  assert.notEqual(index, -1, `missing struct field: ${name}`);
  return struct.values[index];
}

function listValues(list) {
  return list.value.slice(list.start, list.end);
}

function enumTag(value) {
  return value.tag.value;
}

function stats(samples) {
  assert.ok(samples.length > 0);
  const ordered = [...samples].sort((a, b) => a - b);
  const mean = samples.reduce((sum, value) => sum + value, 0) / samples.length;
  const variance =
    samples.reduce((sum, value) => sum + (value - mean) ** 2, 0) / samples.length;
  const percentile = (fraction) => ordered[Math.ceil(ordered.length * fraction) - 1];
  return {
    unit: "microseconds",
    samples: samples.length,
    p50: percentile(0.5),
    p95: percentile(0.95),
    variance,
  };
}

function timeStage(samples, name, action) {
  const started = performance.now();
  const value = action();
  samples[name].push(elapsed(started));
  return value;
}

function assertConverged(actual, expected, context) {
  assert.ok(equal(actual, expected), `${context}: patched and fresh stores diverged`);
}

function runSequence(size, measured) {
  const samples = Object.fromEntries(
    ["updater", "projection", "dataDiff", "encode", "decode", "apply"].map((name) => [
      name,
      [],
    ]),
  );
  const input = make_workload_input(size, seed);
  const operations = listValues(field(input, "ops"));
  let state = field(input, "base");
  let clientStore = project_state(state);
  const cases = [];

  for (const operation of operations) {
    const caseName = enumTag(operation);
    const nextState = timeStage(samples, "updater", () => apply_domain_op(state, operation));
    const freshStore = timeStage(samples, "projection", () => project_state(nextState));
    const changes = timeStage(samples, "dataDiff", () =>
      diff_twig(clientStore, freshStore, diffOptions),
    );
    const encoded = timeStage(samples, "encode", () => calcit.format_cirru_edn(changes));
    const decoded = timeStage(samples, "decode", () => calcit.parse_cirru_edn(encoded));
    const patchedStore = timeStage(samples, "apply", () => patch_twig(clientStore, decoded));
    assertConverged(patchedStore, freshStore, caseName);
    if (caseName === "noop") {
      assert.equal(listValues(changes).length, 0, "no-op must emit no data patch");
      assert.strictEqual(patchedStore, clientStore, "no-op must preserve the client baseline");
    }
    cases.push({
      name: caseName,
      patchOperations: listValues(changes).length,
      encodedBytes: Buffer.byteLength(encoded),
    });
    state = nextState;
    clientStore = patchedStore;
  }

  if (!measured) return { input, operations, finalStore: clientStore };
  return { input, operations, finalStore: clientStore, samples, cases };
}

function makeEnvelopes(size) {
  const input = make_workload_input(size, seed);
  const operations = listValues(field(input, "ops"));
  let state = field(input, "base");
  let store = project_state(state);
  let revision = 0;
  const envelopes = [];
  for (const operation of operations) {
    const nextState = apply_domain_op(state, operation);
    const nextStore = project_state(nextState);
    envelopes.push({
      baseRevision: revision,
      revision: revision + 1,
      changes: diff_twig(store, nextStore, diffOptions),
      expected: nextStore,
    });
    state = nextState;
    store = nextStore;
    revision += 1;
  }
  return { initialStore: project_state(field(input, "base")), envelopes, finalStore: store };
}

function applyEnvelope(client, envelope) {
  const oldStore = client.store;
  if (
    envelope === null ||
    typeof envelope !== "object" ||
    envelope.baseRevision !== client.revision ||
    envelope.revision !== client.revision + 1 ||
    envelope.changes?.value === undefined
  ) {
    return { accepted: false, client };
  }
  const result = try_patch_twig(client.store, envelope.changes);
  if (enumTag(result) !== "ok") return { accepted: false, client };
  const next = { revision: envelope.revision, store: result.extra[0] };
  assert.strictEqual(client.store, oldStore, "patch attempt mutated the old baseline");
  return { accepted: true, client: next };
}

function acknowledge(server, revision) {
  if (server.pending === null || revision !== server.pending.revision) {
    return { accepted: false, server };
  }
  return {
    accepted: true,
    server: {
      acknowledgedRevision: revision,
      baseline: server.pending.expected,
      pending: null,
    },
  };
}

function verifyProtocolFailures(size) {
  const { initialStore, envelopes, finalStore } = makeEnvelopes(size);
  let client = { revision: 0, store: initialStore };

  const future = applyEnvelope(client, envelopes[1]);
  assert.equal(future.accepted, false, "out-of-order patch must be rejected");
  assert.strictEqual(future.client, client, "out-of-order rejection must preserve baseline");

  const wrongRevision = applyEnvelope(client, { ...envelopes[0], baseRevision: 99 });
  assert.equal(wrongRevision.accepted, false, "wrong revision must be rejected");
  assert.strictEqual(wrongRevision.client, client, "wrong revision must preserve baseline");

  const invalid = applyEnvelope(client, { ...envelopes[0], changes: "invalid" });
  assert.equal(invalid.accepted, false, "invalid payload must be rejected");
  assert.strictEqual(invalid.client, client, "invalid payload must preserve baseline");

  for (const envelope of envelopes) client = applyEnvelope(client, envelope).client;
  assertConverged(client.store, finalStore, "slow-client recovery");

  const duplicatePatch = applyEnvelope(client, envelopes.at(-1));
  assert.equal(duplicatePatch.accepted, false, "duplicate patch must be rejected");
  assert.strictEqual(duplicatePatch.client, client, "duplicate patch must preserve baseline");

  const pendingServer = {
    acknowledgedRevision: 0,
    baseline: initialStore,
    pending: envelopes[0],
  };
  const outOfOrderAck = acknowledge(pendingServer, envelopes[1].revision);
  assert.equal(outOfOrderAck.accepted, false, "out-of-order acknowledgement must be rejected");
  assert.strictEqual(outOfOrderAck.server, pendingServer, "rejected ack must preserve baseline");
  const acceptedAck = acknowledge(pendingServer, envelopes[0].revision);
  assert.equal(acceptedAck.accepted, true, "matching acknowledgement must advance baseline");
  assert.strictEqual(acceptedAck.server.baseline, envelopes[0].expected);
  const duplicateAck = acknowledge(acceptedAck.server, envelopes[0].revision);
  assert.equal(duplicateAck.accepted, false, "duplicate acknowledgement must be rejected");
  assert.strictEqual(duplicateAck.server, acceptedAck.server, "duplicate ack must preserve baseline");

  const foreign = make_workload_input(size, seed + 99);
  const foreignStore = project_state(field(foreign, "base"));
  const corruptCandidate = patch_twig(foreignStore, envelopes[1].changes);
  assert.throws(
    () => assertConverged(corruptCandidate, envelopes[1].expected, "corrupt patch oracle"),
    /diverged/,
    "the convergence oracle must fail for a corrupt baseline",
  );

  return {
    slowClientQueuedPatches: envelopes.length,
    outOfOrderPatchRejected: true,
    duplicatePatchRejected: true,
    outOfOrderAckRejected: true,
    duplicateAckRejected: true,
    wrongRevisionRejected: true,
    invalidPayloadRejected: true,
    recoveryConverged: true,
    corruptPatchOracleFailed: true,
  };
}

const results = [];
for (const size of sizes) {
  for (let index = 0; index < warmups; index += 1) runSequence(size, false);
  const accumulated = Object.fromEntries(
    ["updater", "projection", "dataDiff", "encode", "decode", "apply"].map((name) => [
      name,
      [],
    ]),
  );
  let last;
  for (let index = 0; index < repetitions; index += 1) {
    last = runSequence(size, true);
    for (const name of Object.keys(accumulated)) accumulated[name].push(...last.samples[name]);
  }
  results.push({
    entityCount: size,
    seed,
    operationCount: last.operations.length,
    inputHash: sha256(last.input.toString()),
    cases: last.cases,
    stages: Object.fromEntries(
      Object.entries(accumulated).map(([name, samples]) => [name, stats(samples)]),
    ),
    allocations: { status: "unavailable", reason: "no stable per-stage allocator API" },
    protocol: verifyProtocolFailures(size),
  });
}

const dependencyFiles = ["calcit.cirru", "deps.cirru", "package.json"];
const report = {
  schemaVersion: 1,
  mode,
  environment: {
    platform: process.platform,
    release: os.release(),
    architecture: process.arch,
    node: process.version,
    calcitRuntime: calcit.calcit_version,
    cpu: os.cpus()[0]?.model ?? "unknown",
    dependencyArtifactHash: sha256(
      dependencyFiles.map((path) => fs.readFileSync(path)).reduce((all, part) => Buffer.concat([all, part])),
    ),
  },
  command: `yarn workload:${mode === "full" ? "benchmark" : "smoke"}`,
  warmups,
  repetitions,
  results,
};
report.rawHash = sha256(JSON.stringify(report));
const output = `${JSON.stringify(report, null, 2)}\n`;
if (args.has("--out")) fs.writeFileSync(args.get("--out"), output);
process.stdout.write(output);

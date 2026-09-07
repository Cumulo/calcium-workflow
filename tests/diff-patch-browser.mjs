import * as calcit from "/js-out/calcit.core.mjs";
import {
  activate_instance_$x_ as activateInstance,
  patch_instance_$x_ as patchInstance,
} from "/js-out/respo.controller.client.mjs";
import { find_element_diffs as findElementDiffs } from "/js-out/respo.render.diff.mjs";
import {
  apply_domain_op,
  make_workload_input,
  project_state,
  workload_view,
} from "/js-out/app.workload.diff-patch.mjs";
import { allocationUnavailable, listValues, stats } from "/tests/workload-shared.mjs";

const params = new URLSearchParams(location.search);
const mode = params.get("mode") ?? "smoke";
const seed = Number(params.get("seed") ?? 794);
const repetitions = Number(params.get("repetitions") ?? (mode === "full" ? 30 : 2));
const warmups = Number(params.get("warmups") ?? (mode === "full" ? 5 : 1));
const sizes = mode === "full" ? [1_000, 10_000] : [100];
const mount = document.querySelector("#mount");
const fresh = document.querySelector("#fresh");
const status = document.querySelector("#status");
const resultNode = document.querySelector("#result");
const emptyCoord = calcit._$L_();

function field(struct, name) {
  const index = struct.fields.findIndex((item) => item.value === name);
  if (index < 0) throw new Error(`missing struct field: ${name}`);
  return struct.values[index];
}

function invariant(condition, message) {
  if (!condition) throw new Error(message);
}

function runBrowserSequence(size, measured) {
  mount.replaceChildren();
  fresh.replaceChildren();
  let listenerEvents = 0;
  const deliverEvent = () => {
    listenerEvents += 1;
  };
  const input = make_workload_input(size, seed);
  const operations = listValues(field(input, "ops"));
  let state = field(input, "base");
  let store = project_state(state);
  let tree = workload_view(store);
  activateInstance(tree, mount, deliverEvent);

  const focusProbe = mount.querySelector("#workload-focus-probe");
  invariant(focusProbe !== null, "focus probe was not rendered");
  focusProbe.focus();
  focusProbe.setSelectionRange(2, 5);
  focusProbe.dispatchEvent(new Event("input", { bubbles: true }));
  invariant(listenerEvents === 1, "initial listener did not fire");
  let trackedRow = mount.querySelector(`[data-name="entity-${seed}-0"]`);
  invariant(trackedRow !== null, "tracked keyed row was not rendered");

  const vdomDiff = [];
  const domWrite = [];
  const cases = [];
  for (const operation of operations) {
    const caseName = operation.tag.value;
    const nextState = apply_domain_op(state, operation);
    const nextStore = project_state(nextState);
    const nextTree = workload_view(nextStore);
    const domOperations = [];
    const beforeHtml = caseName === "noop" ? mount.innerHTML : null;
    const diffStarted = performance.now();
    findElementDiffs((change) => domOperations.push(change), emptyCoord, emptyCoord, tree, nextTree);
    vdomDiff.push((performance.now() - diffStarted) * 1_000);
    const writeStarted = performance.now();
    patchInstance(calcit.arrayToList(domOperations), mount, deliverEvent);
    domWrite.push((performance.now() - writeStarted) * 1_000);

    activateInstance(nextTree, fresh, () => {});
    invariant(mount.innerHTML === fresh.innerHTML, `${caseName}: patched DOM differs from fresh render`);
    if (caseName === "noop") {
      invariant(domOperations.length === 0, "no-op emitted DOM mutations");
      invariant(mount.innerHTML === beforeHtml, "no-op changed DOM markup");
    }
    invariant(mount.querySelector("#workload-focus-probe") === focusProbe, `${caseName}: focus node replaced`);
    invariant(document.activeElement === focusProbe, `${caseName}: focus was lost`);
    invariant(
      focusProbe.selectionStart === 2 && focusProbe.selectionEnd === 5,
      `${caseName}: text selection changed`,
    );
    focusProbe.dispatchEvent(new Event("input", { bubbles: true }));
    invariant(listenerEvents === cases.length + 2, `${caseName}: listener stopped firing`);
    if (caseName !== "replace") {
      invariant(
        mount.querySelector(`[data-name="entity-${seed}-0"]`) === trackedRow,
        `${caseName}: stable keyed row was replaced`,
      );
    }
    const effectOperations = domOperations.filter((change) => change.tag.value.startsWith("effect-"));
    invariant(effectOperations.length === 0, `${caseName}: stable ref emitted effect churn`);
    cases.push({
      name: caseName,
      domOperations: domOperations.length,
      effectOperations: effectOperations.length,
    });
    state = nextState;
    store = nextStore;
    tree = nextTree;
  }
  return measured ? { vdomDiff, domWrite, cases, listenerEvents } : null;
}

try {
  const results = [];
  for (const size of sizes) {
    for (let index = 0; index < warmups; index += 1) runBrowserSequence(size, false);
    const samples = { vdomDiff: [], domWrite: [] };
    let last;
    for (let index = 0; index < repetitions; index += 1) {
      last = runBrowserSequence(size, true);
      samples.vdomDiff.push(...last.vdomDiff);
      samples.domWrite.push(...last.domWrite);
    }
    results.push({
      entityCount: size,
      seed,
      cases: last.cases,
      stages: {
        vdomDiff: { ...stats(samples.vdomDiff), allocation: allocationUnavailable },
        domWrite: { ...stats(samples.domWrite), allocation: allocationUnavailable },
      },
      allocations: allocationUnavailable,
      semantics: {
        patchedEqualsFreshRender: true,
        keyIdentityPreserved: true,
        stableRefHasNoEffectChurn: true,
        listenerSurvivesPatches: true,
        focusAndSelectionPreserved: true,
        noOpHasNoDomMutation: true,
      },
    });
  }
  const report = {
    schemaVersion: 1,
    mode,
    command:
      mode === "full"
        ? "http://127.0.0.1:5173/tests/diff-patch-browser.html?mode=full"
        : "http://127.0.0.1:5173/tests/diff-patch-browser.html",
    environment: {
      userAgent: navigator.userAgent,
      platform: navigator.platform,
      hardwareConcurrency: navigator.hardwareConcurrency ?? "unavailable",
    },
    warmups,
    repetitions,
    results,
    rawHashScope: "full report excluding rawHash; includes environment and timing",
  };
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(JSON.stringify(report)),
  );
  report.rawHash = [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  window.__CALCIUM_WORKLOAD_RESULT__ = report;
  status.textContent = "passed";
  resultNode.textContent = JSON.stringify(report, null, 2);
} catch (error) {
  window.__CALCIUM_WORKLOAD_ERROR__ = error.stack ?? String(error);
  status.textContent = "failed";
  resultNode.textContent = window.__CALCIUM_WORKLOAD_ERROR__;
  throw error;
}

import fs from "node:fs";

const baseline = JSON.parse(fs.readFileSync("config/calcit-upgrade-baseline.json", "utf8"));
const reports = {
  types: JSON.parse(fs.readFileSync(".calcit/upgrade/check-types.json", "utf8")).data.summary,
  weak: JSON.parse(fs.readFileSync(".calcit/upgrade/weak-types.json", "utf8")).data.summary,
  deprecated: JSON.parse(fs.readFileSync(".calcit/upgrade/deprecated.json", "utf8")).data.summary,
};

const current = {
  typeNone: reports.types.levels.none,
  typeNotFull: reports.types.levels.none + reports.types.levels.partial,
  schemaDynamic: reports.weak.kinds["schema-dynamic"] ?? 0,
  codeDynamic: reports.weak.kinds["code-dynamic"] ?? 0,
  codeNil: reports.weak.kinds["code-nil"] ?? 0,
  declaredOptional: reports.weak.intents["declared-optional"] ?? 0,
  unresolved: reports.weak.intents["unresolved"] ?? 0,
  deprecatedCalls: reports.deprecated.calls,
};

const failures = [];
for (const key of Object.keys(current)) {
  if (!(key in baseline)) {
    failures.push(`${key}: missing baseline metric`);
    continue;
  }
  if (!Number.isFinite(baseline[key])) {
    failures.push(`${key}: baseline is not a finite number`);
    continue;
  }
  if (!Number.isFinite(current[key])) {
    failures.push(`${key}: current value is not a finite number`);
    continue;
  }
  if (current[key] > baseline[key]) failures.push(`${key}: ${current[key]} > ${baseline[key]}`);
}
for (const key of Object.keys(baseline)) {
  if (!(key in current)) failures.push(`${key}: unknown baseline metric`);
}
for (const key of Object.keys(current)) {
  console.log(`${key}: ${current[key]} (baseline ${baseline[key] ?? "unset"})`);
}
if (failures.length > 0) {
  console.error(`Calcit upgrade baseline exceeded: ${failures.join(", ")}`);
  process.exit(1);
}

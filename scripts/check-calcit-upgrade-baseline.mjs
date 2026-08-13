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
  deprecatedCalls: reports.deprecated.calls,
};

const failures = Object.keys(baseline).filter((key) => current[key] > baseline[key]);
for (const key of Object.keys(current)) {
  console.log(`${key}: ${current[key]} (baseline ${baseline[key] ?? "unset"})`);
}
if (failures.length > 0) {
  console.error(`Calcit upgrade baseline exceeded: ${failures.join(", ")}`);
  process.exit(1);
}

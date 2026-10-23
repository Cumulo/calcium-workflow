import { listToArray } from "../js-out/calcit.core.mjs";

export const allocationUnavailable = Object.freeze({
  status: "unavailable",
  reason: "no stable per-stage allocator API",
});

export function listValues(list) {
  return listToArray(list);
}

export function stats(samples) {
  if (samples.length === 0) throw new Error("statistics require at least one sample");
  const ordered = [...samples].sort((a, b) => a - b);
  const mean = samples.reduce((sum, value) => sum + value, 0) / samples.length;
  const percentile = (fraction) => ordered[Math.ceil(ordered.length * fraction) - 1];
  return {
    unit: "microseconds",
    samples: samples.length,
    p50: percentile(0.5),
    p95: percentile(0.95),
    variance:
      samples.reduce((sum, value) => sum + (value - mean) ** 2, 0) / samples.length,
  };
}

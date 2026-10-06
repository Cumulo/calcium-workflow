// bottom-tip 0.1.5 relies on bundler extension resolution. Keep its real
// implementation in Node regressions, resolving only this known legacy import.
export function resolve(specifier, context, nextResolve) {
  if (specifier === "virtual-dom/create-element" &&
      context.parentURL?.endsWith("/bottom-tip/lib/bottom-tip.js")) {
    return nextResolve(`${specifier}.js`, context);
  }
  return nextResolve(specifier, context);
}

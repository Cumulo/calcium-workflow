import { register } from "node:module";

register(new URL("./node-resolution-hooks.mjs", import.meta.url));

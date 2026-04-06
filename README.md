## Calcium workflow

> template for mini realtime apps, based on calcit-js eco. But with calcit-rs runtime.

### Usages

Install Node.js, Yarn, [Calcit](https://github.com/calcit-lang/calcit) to start.

Clone dependencies into `~/.config/calcit/modules/` with `caps` command from Calcit.

Code with [calcit-editor](https://github.com/calcit-lang/editor).

Run frontend:

```bash
# dev mode
corepack enable && corepack prepare yarn@4.12.0 --activate
yarn install --immutable
caps
yarn watch-page
yarn vite # for browser app

# release mode
caps --ci
yarn install --immutable
yarn compile-page
yarn release-page
```

Run backend in calcit-rs:

```bash
# dev mode
mode=dev cr compact.cirru --entry server -w

# release mode
cr compact.cirru --entry server
```

### License

MIT

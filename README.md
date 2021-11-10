
Calcium workflow
----

> template for mini realtime apps, based on calcit-js eco. But with calcit-rs runtime.

### Usages

Install Node.js, Yarn, [Calcit](https://github.com/calcit-lang/calcit_runner.rs) to start.

Notice that you need to clone dependencies into `.config/calcit/modules/` manually.

Code with [calcit-editor](https://github.com/Cirru/calcit-editor).

Run frontend:

```bash
yarn

yarn watch-page # watch compile page code

yarn vite # for browser app
```

Run backend in calcit-rs:

```bash
cr
```

### License

MIT

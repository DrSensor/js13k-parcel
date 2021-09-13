# js13k template

> with parcel (and nix flake)

## Setup

There is 2 (4 if you count pnpm and yarn) way to setup.

### using **npm**

In this approach, no linter or formatter are installed. Only `parcel`.

Install all dependencies via:

```sh
npm install
```

then you can run the project using:

```sh
npx parcel serve index.html
```

or build for production using:

```sh
# for browser bundle
npx parcel build index.html --target {desktop,mobile,xr} # choose one

# build to run in nodejs (server), not browser
npx parcel build server.ts --target server
```

### using **nix** (experimental)

This require [nix flake to be enabled](https://serokell.io/blog/practical-nix-flakes#getting-started-with-nix). This approach will automatically install both project dependencies and all toolchains like linter, formatter, and nodejs.

- linter: [dlint](https://github.com/denoland/deno_lint)
- formatter: [dprint](https://dprint.dev)

> [**TOFU**](https://github.com/msteen/nix-prefetch/#tofu): [Supply all (or one of the platform) sha256](./integrity.nix) first before running any nix command.

#### dev environment

Run this once or twice to enter the development environment.

```sh
nix develop
```

#### TODO: build for production

You can build for all target:
```sh
nix build
```

or specify which target to build:
```sh
nix build '.#desktop' # or '.#mobile' or '.#xr' or '.#server'
```

### cleanup

In case unexpected things happen.

```sh
rm .parcel-cache/ dist/ node_modules/ -fr
rm package-lock.json yarn.lock pnpm-lock.yaml -f
```

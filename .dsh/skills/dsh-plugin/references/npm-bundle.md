# Profile-scoped npm bundle

Use an npm bundle when the plugin needs profile-level installation, a portable dependency specifier, or an independent release cycle. In this repository, keep its source under `packages/<package>/`.

## Package boundary

Prefer TypeScript source compiled to ordinary ESM JavaScript. A minimal publishable layout is:

```text
packages/<package>/
├── src/index.ts
├── test/
├── lib/                  # generated
├── cordis.patch.yml
├── package.json
├── tsconfig.json
├── tsdown.config.ts
├── README.md
└── LICENSE
```

The manifest must make the bundle contract and tarball explicit:

```json
{
  "name": "@scope/dsh-example",
  "version": "0.1.0",
  "type": "module",
  "main": "./lib/index.js",
  "types": "./lib/index.d.ts",
  "exports": {
    ".": {
      "types": "./lib/index.d.ts",
      "default": "./lib/index.js"
    },
    "./package.json": "./package.json"
  },
  "files": ["lib", "cordis.patch.yml", "README.md", "LICENSE"],
  "publishConfig": { "access": "public" },
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
}
```

The patch references the installed package name, never the source checkout:

```yaml
- insert:
    - id: example
      name: '@scope/dsh-example'
```

Put imported runtime libraries in `dependencies`. Put host-provided DSH/Cordis APIs in compatible `peerDependencies` and in `devDependencies` for local typechecking. Align versions with the profile's actual DSH release instead of guessing. Use a `files` allowlist and include every required license or third-party notice.

## Profile wiring

The ordinary consumer command is:

```sh
dsh plugin --profile <profile> add @scope/dsh-example
```

Keep portable registry ranges in the profile's `package.json`, list the package once in `dsh.profile.bundles`, carry a matching lockfile, and preserve the user's exact profile set.

When pnpm's release-age policy blocks a just-published version, add only that exact package version to `minimumReleaseAgeExclude`, regenerate the lock, and keep the exclusion synchronized with the locked release. Finish with a frozen install in the profile.

## Release gate

Before publication:

```sh
pnpm run check
npm pack --dry-run --json
npm whoami
```

Inspect the complete tarball list: runtime JavaScript, declarations, patch, manifest, README, and licenses must be present; source, tests, caches, and credentials must be absent. Install or import an actual packed artifact in an isolated consumer when module resolution changed.

Each npm version is immutable. Bump the version for every metadata or code change, obtain explicit authorization for the external publish, and complete npm 2FA in an interactive TTY when required:

```sh
npm publish --access public
npm view @scope/dsh-example version dist.integrity --json
```

After publication, resolve the registry artifact into every requested profile, regenerate and freeze its lockfile, install the live profile, and verify both `dsh plugin ... why` and `dsh --dump-config`. The branch is complete when npm integrity equals the lockfile integrity and the installed profile reports the published version.

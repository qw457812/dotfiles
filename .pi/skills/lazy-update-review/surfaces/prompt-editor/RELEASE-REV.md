# Resolve an npm revision without gitHead

Use only for the frozen old or target artifact whose `gitHead` is missing. Bind the provenance statement to the exact package digest; a matching Git tag is insufficient.

```bash
set -euo pipefail
ARTIFACT='exact-name@exact-version'
META=$(npm view "$ARTIFACT" name version dist.tarball dist.integrity dist.attestations.url --json)
URL=$(node -e '
  const value = JSON.parse(process.argv[1]);
  const meta = Array.isArray(value) ? value[0] : value;
  const url = meta?.["dist.attestations.url"];
  if (!url) throw Error("No provenance URL");
  process.stdout.write(url);
' "$META")
curl -fsSL "$URL" | node -e '
  const fs = require("node:fs");
  const value = JSON.parse(process.argv[1]);
  const meta = Array.isArray(value) ? value[0] : value;
  const integrity = meta["dist.integrity"];
  if (!integrity.startsWith("sha512-")) throw Error("Expected sha512 package integrity");
  const sha512 = Buffer.from(integrity.slice(7), "base64").toString("hex");
  const { attestations } = JSON.parse(fs.readFileSync(0, "utf8"));
  const statements = attestations.map(a =>
    JSON.parse(Buffer.from(a.bundle.dsseEnvelope.payload, "base64").toString("utf8")));
  const source = statements.find(s => s.predicateType === "https://slsa.dev/provenance/v1" &&
    s.subject.some(subject => subject.digest.sha512 === sha512));
  if (!source) throw Error("No provenance matching package integrity");
  console.log(JSON.stringify({ package: meta.name, version: meta.version,
    tarball: meta["dist.tarball"], integrity,
    sources: source.predicate.buildDefinition.resolvedDependencies }, null, 2));
' "$META"
```

Use the `gitCommit` for the expected Pi or pi-vim repository and confirm it exists in the matching librarian cache. The digest check matches npm metadata; it does not verify the attestation signature independently.

**Done when:** package, version, tarball integrity, expected source repository and cached commit are recorded. If provenance is absent, malformed or points elsewhere, mark the source range unresolved; exact-artifact validation remains possible.

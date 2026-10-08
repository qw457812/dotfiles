# Published revision without npm gitHead

Follow when an exact npm version has no `gitHead`. Resolve the source from that
artifact's npm provenance, not from the repository's current HEAD or a tag alone.

## Resolve and bind the artifact

Use the frozen package and version from `REVIEW.md`:

```bash
set -euo pipefail
META=$(mktemp)
ATTESTATION=$(mktemp)
npm view "$PI_TARGET_PACKAGE@$PI_TARGET_VERSION" --json > "$META"
URL=$(node -e 'const m=JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")); if (!m.dist?.attestations?.url) throw Error("No provenance URL"); console.log(m.dist.attestations.url)' "$META")
curl -fsSL "$URL" > "$ATTESTATION"
node - "$META" "$ATTESTATION" <<'JS'
const fs = require('node:fs');
const meta = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const attestations = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
const integrity = meta.dist.integrity;
if (!integrity.startsWith('sha512-')) throw Error('Expected sha512 package integrity');
const sha512 = Buffer.from(integrity.slice(7), 'base64').toString('hex');
const statements = attestations.attestations.map(a =>
  JSON.parse(Buffer.from(a.bundle.dsseEnvelope.payload, 'base64').toString('utf8')));
const source = statements.find(s => s.predicateType === 'https://slsa.dev/provenance/v1' &&
  s.subject.some(subject => subject.digest.sha512 === sha512));
if (!source) throw Error('No provenance matching package integrity');
console.log(JSON.stringify({ package: meta.name, version: meta.version,
  tarball: meta.dist.tarball, integrity,
  sources: source.predicate.buildDefinition.resolvedDependencies }, null, 2));
JS
```

Record the `gitCommit` of the expected Pi repository as the revision. Check its
existence in the librarian cache and compare its exact range. For a missing old
revision, repeat with the installed package's exact name and version.

The digest check binds the decoded statement to npm metadata; it is not independent
cryptographic verification of the attestation signature. If provenance is absent,
malformed, or points to another repository, report the source range as unresolved.
Published target declarations can still be tested in isolation, but do not call the
source-range review complete.

**Complete when:** package/version, tarball integrity, provenance source repository,
and immutable source hash are recorded, the hash exists locally, and any difference
from lazy's target is classified.

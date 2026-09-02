# The runner's reviewed base images

`build-runner.sh` refuses a `PYTHON_BASE` or `NODE_BASE` that is not digest-pinned, but
until 2026-08-29 nothing recorded **which** digests had been reviewed: the values lived only
in the CI project's gitignored tfvars, and when that project was deleted they went with it.
A rebuild then had to re-derive them, which is a new review decision wearing the clothes of
a restoration. This file is the record so that does not happen twice.

## Current pins

| Runtime key | Base | Digest | Reviewed |
|---|---|---|---|
| `python3.12-node20` | `python:3.12-slim-bookworm` | `sha256:4427763a1ba36f5aa8f656a03e5d00f3b8d61f5dd950c73df6c14f8c7640f8ab` | 2026-08-29 |
| `python3.12-node20` | `node:20-bookworm-slim` | `sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0` | 2026-08-29 |
| `python3.14-node24` | `python:3.14-slim-bookworm` | `sha256:416f0db2a2b561945630cef9877a7ea0581b27449eb9fd9df42f03e1b74b5b63` | 2026-08-29 |
| `python3.14-node24` | `node:24-bookworm-slim` | `sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e` | 2026-08-29 |

Build with them exactly:

```bash
RUNTIME_KEY="python3.12-node20" \
PYTHON_BASE="python:3.12-slim-bookworm@sha256:4427763a1ba36f5aa8f656a03e5d00f3b8d61f5dd950c73df6c14f8c7640f8ab" \
NODE_BASE="node:20-bookworm-slim@sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0" \
IMAGE_URI="<REGION>-docker.pkg.dev/<CI_PROJECT>/grc-ci-runner/runner-python3.12-node20:staging-<date>" \
bash ci/gcp/runner/build-runner.sh
```

```bash
RUNTIME_KEY="python3.14-node24" \
PYTHON_BASE="python:3.14-slim-bookworm@sha256:416f0db2a2b561945630cef9877a7ea0581b27449eb9fd9df42f03e1b74b5b63" \
NODE_BASE="node:24-bookworm-slim@sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e" \
IMAGE_URI="<REGION>-docker.pkg.dev/<CI_PROJECT>/grc-ci-runner/runner-python3.14-node24:staging-<date>" \
bash ci/gcp/runner/build-runner.sh
```

Then scan before enabling triggers, which is what the script's closing line asks for:

```bash
trivy image --exit-code 1 --ignore-unfixed --severity HIGH,CRITICAL <image>@sha256:<digest>
```

## Why the two in-image version pins exist

Both were added on 2026-08-29 because the first rebuilt runner failed that scan with **32
fixable HIGH/CRITICAL findings**, and neither cause is fixed by moving the base digests
forward:

- **`TERRAFORM_VERSION`** carried 19 of the 32 — Go `stdlib` and `archive/tar` CVEs embedded
  in the release binary. Bumped 1.15.9 → 1.16.0. This is the third time that binary has been
  the image's largest single source of findings; the Dockerfile comment carries the history.
- **`NPM_VERSION`** carried 11 — all inside npm's own bundled dependencies
  (`brace-expansion`, `minimatch`, `cross-spawn`, `glob`, `ip-address`, `pacote`,
  `sigstore`). The npm shipped inside a Node base never moves, and Node 20 is fixed by the
  fleet's runtime key, so a patched npm is installed over it.

**`NPM_VERSION` is not a free-floating "latest".** npm 12 requires Node `>= 22` and refuses
to install on a Node 20 base — the build fails outright rather than degrading. `11.9.0` is the
newest release whose engines still accept Node 20. Anything that bumps this pin must check
`npm view npm@<version> engines` first. `build-runner.sh` now derives the default per Node
major (11 below Node 22, 12 at or above it) and refuses a mismatched override, so the pair
cannot be got wrong from the command line.

## The move to Node 24, and what it actually bought

The fleet moved to `python3.14-node24` on 2026-08-29. Two predictions this file made about
that move were wrong, and both are worth keeping written down.

**"A current Node base bundles a current npm, so installing another one buys nothing" was
wrong.** `node:24-bookworm-slim` bundles npm 11.9.0 — the very version the Node 20 runner
was installing over its base. Dropping the install would have carried all 13 npm findings
forward. Installing npm `12.0.2` over it cleared **9 of 13**.

**The `NPM_VERSION` arg was never reaching the build.** `build-runner.sh` did not forward it
as a `--build-arg`, so the Dockerfile's `ARG` default was the only value any build could
produce and the pin was un-overridable from outside. The first `python3.14-node24` image
therefore shipped npm 11.9.0 while appearing to be configurable. Fixed by forwarding the arg
and by asserting `npm --version` in the post-build smoke test beside the Python and Node
assertions, because a silently-unchanged component is exactly the failure that occurred.

### Scan status at the move (2026-08-29)

`python3.14-node24@sha256:63c7395b2e77d647ddb373a57db75335e5278017b5828589f981d391bccdb7d7`
returns **15 fixable HIGH/CRITICAL**, against 24 for both the previous node24 build and the
live `python3.12-node20` runner. It is a strict improvement on the runtime it replaces, and
it is **not zero**. What remains:

- **9 × Go `stdlib` in `usr/local/bin/terraform`** — the fix versions are Go `1.26.6`/`1.25.13`
  and Terraform 1.16.0 embeds Go 1.26.4. **1.16.0 is the newest stable release**, so unlike
  every previous occurrence this one cannot be bumped away: no shipped Terraform carries the
  fixed runtime yet. Re-scan and bump `TERRAFORM_VERSION` when 1.16.1 (or later) publishes.
  The live Node 20 runner carries the identical nine, so this is a standing fleet exposure
  rather than anything the Node 24 move introduced.
- **4 × npm's own bundled dependencies** (`brace-expansion`, `ip-address`, `tar`) — inside
  npm 12.0.2 itself, so they clear when npm next patches them, not before.
- **2 false positives**: `setuptools 70.3.0` and `msgpack 1.1.2` are reported with **no
  `FilePath`**, attributed to a parent layer. Verified against the merged filesystem:
  setuptools is not present anywhere in the image (`find` finds nothing; it is absent from
  `importlib.metadata`), and the only installed msgpack is **1.2.1**, the fixed version the
  runner lock pins. Do not chase these; do not "fix" them by pinning something.

The consequence for the operator step below: `--exit-code 1` will fail on this image. The
runbook's instruction to scan before enabling triggers still stands — read the findings
against this list rather than treating a non-zero exit as a new regression.

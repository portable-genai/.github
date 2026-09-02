#!/usr/bin/env bash
set -euo pipefail

readonly runtime_key="${RUNTIME_KEY:-}"
readonly python_base="${PYTHON_BASE:-}"
readonly node_base="${NODE_BASE:-}"
readonly image_uri="${IMAGE_URI:-}"

if [[ ! "$runtime_key" =~ ^python3\.(12|13|14)-node(20|22|24)$ ]]; then
  echo "RUNTIME_KEY must be an approved Python/Node pair" >&2
  exit 2
fi
python_version="${runtime_key#python}"
python_version="${python_version%%-node*}"
node_version="${runtime_key##*-node}"
if [[ ! "$python_base" =~ ^python:${python_version}-slim-bookworm@sha256:[0-9a-f]{64}$ ]]; then
  echo "PYTHON_BASE must be the official python:${python_version}-slim-bookworm digest" >&2
  exit 2
fi
if [[ ! "$node_base" =~ ^node:${node_version}-bookworm-slim@sha256:[0-9a-f]{64}$ ]]; then
  echo "NODE_BASE must be the official node:${node_version}-bookworm-slim digest" >&2
  exit 2
fi
if [[ ! "$image_uri" =~ /(ci-)?runner-${runtime_key}:[A-Za-z0-9._-]+$ ]]; then
  echo "IMAGE_URI must target (ci-)runner-${runtime_key} with a staging tag" >&2
  exit 2
fi

# npm is pinned per Node major, because the majors are not interchangeable: npm 12 refuses
# to install on Node < 22, so a node20 runner stays on npm 11 and a node24 runner takes the
# current npm. The Dockerfile's ARG default was previously the ONLY value this build could
# produce -- the arg was never forwarded -- so the node24 runner silently kept npm 11.9.0
# and the CVE fixes that motivated the Node bump never arrived. Overridable via NPM_VERSION,
# but the major is then checked against the Node major rather than trusted.
if ((node_version >= 22)); then
  npm_version="${NPM_VERSION:-12.0.2}"
  npm_major_min=12
else
  npm_version="${NPM_VERSION:-11.9.0}"
  npm_major_min=11
fi
npm_major="${npm_version%%.*}"
if ((node_version >= 22 && npm_major < 12)) || ((node_version < 22 && npm_major >= 12)); then
  echo "NPM_VERSION $npm_version does not match node${node_version} (needs npm ${npm_major_min}.x)" >&2
  exit 2
fi

docker buildx build \
  --load \
  --platform linux/amd64 \
  --build-arg "PYTHON_BASE=$python_base" \
  --build-arg "NODE_BASE=$node_base" \
  --build-arg "NPM_VERSION=$npm_version" \
  --tag "$image_uri" \
  "$(dirname "$0")"

# The npm assertion is part of the smoke test for the same reason the arg is forwarded: a
# silently-unchanged npm is exactly the failure this build had.
docker run --rm --entrypoint /bin/sh "$image_uri" -c \
  "python3 -c 'import sys; assert sys.version_info[:2] == tuple(map(int, \"${python_version}\".split(\".\")))' && test \"\$(node --version | cut -d. -f1)\" = v${node_version} && test \"\$(npm --version)\" = ${npm_version}"
# GRC_SKIP_PUSH builds and smoke-tests without publishing to a registry. The fleet distributes
# this image as a release asset, because an organization GHCR package is created private and no
# API can change that -- so there is nothing to push to that the gate could anonymously pull.
if [[ "${GRC_SKIP_PUSH:-0}" == "1" ]]; then
  echo "Built and smoke-tested $image_uri; skipping push (GRC_SKIP_PUSH=1)."
else
  docker push "$image_uri"
  echo "Resolve, scan, and record the immutable digest for $runtime_key before phase two."
fi

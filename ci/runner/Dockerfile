ARG NODE_BASE
ARG PYTHON_BASE

FROM ${NODE_BASE} AS node

FROM ${PYTHON_BASE}

ARG TARGETARCH=amd64
# Terraform is the runner's largest single source of critical-and-high findings once Debian is
# patched, because the release binary embeds its own Go runtime and `golang.org/x/crypto`: at
# 1.13.3 that was 41 of 101. Bumping it is deliberate rather than swept, since the archive is
# checksum-verified below and `tf-validate` jobs run whatever version is here. Moved to 1.15.9
# on 2026-08-23, then to 1.16.0 on 2026-08-29 when a rebuild scan showed 19 of the image's 32
# fixable findings were Go stdlib and archive/tar CVEs carried by the 1.15.9 binary. Both
# checksums come from the published `terraform_1.16.0_SHA256SUMS`.
ARG TERRAFORM_VERSION=1.16.0

# The npm that ships INSIDE the Node base image is the second-largest source of fixable
# findings: 11 of 32 on 2026-08-29, all in npm's own bundled dependencies (brace-expansion,
# minimatch, cross-spawn, glob, ip-address, pacote, sigstore). A base's bundled npm does not
# move once the image is cut, so the only way to clear them without changing every
# repository's runtime is to install a patched npm over it. Moving to Node 24 did NOT make
# that unnecessary, which was the standing prediction: node:24-bookworm-slim bundles npm
# 11.9.0, the same version the Node 20 runner was already installing over its own base.
#
# The value is per Node major and is supplied by build-runner.sh, which derives it (npm 11
# below Node 22, npm 12 at or above, since npm 12 refuses to install on Node < 22) and
# refuses a mismatched override. This default is the Node-20 value and is only a fallback:
# until 2026-08-29 the arg was never forwarded at all, so this line was silently the ONLY
# value any build could produce, and the first Node 24 runner shipped npm 11 while looking
# configurable. Pinned, never floating: `npm@latest` would make the image unreproducible.
ARG NPM_VERSION=11.9.0

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules

COPY requirements-runner.lock /tmp/requirements-runner.lock

# Both suites, at the SAME snapshot timestamp. The security suite is not optional decoration:
# Debian ships patches in bookworm-security, not in bookworm main, so a sources.list carrying
# main alone installs every package at its original release version and can never receive a
# security fix. That is what this file did until 2026-08-23, and the first scan of the image it
# produced returned 182 CRITICAL and 476 HIGH findings, every one of them with a fix available.
# Pinning by snapshot makes the build reproducible; only the second line makes it patched.
#
# **The timestamp is a freshness decision, not a constant.** A snapshot pin freezes the package
# set at a date, so the further it falls behind, the more disclosed-and-fixed vulnerabilities the
# image carries while still building byte-for-byte reproducibly. Move it forward deliberately,
# move both lines together, and re-scan: the pair below is the only thing standing between
# "reproducible" and "reproducibly out of date".
RUN printf '%s\n' \
      'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260826T000000Z bookworm main' \
      'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/20260826T000000Z bookworm-security main' \
      > /etc/apt/sources.list \
    && rm -f /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends ca-certificates chromium curl git make openssl unzip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install -g --no-audit --no-fund "npm@${NPM_VERSION}" \
    && npm cache clean --force \
    && case "$TARGETARCH" in \
         amd64) terraform_sha="41d05b927aa174f15d1228c4eba832a323b716c68b415ef5a00179f46cc602d3" ;; \
         arm64) terraform_sha="60f86cea49a653e22a93c000f16cbfa391ce41c6f6a11d36557c35da411f684c" ;; \
         *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 2 ;; \
       esac \
    && archive="terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
    && curl --fail --silent --show-error --location \
         "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${archive}" \
         --output "/tmp/${archive}" \
    && echo "${terraform_sha}  /tmp/${archive}" | sha256sum -c - \
    && unzip "/tmp/${archive}" terraform -d /usr/local/bin \
    && rm "/tmp/${archive}" \
    && pip install --no-cache-dir --require-hashes -r /tmp/requirements-runner.lock \
    && rm /tmp/requirements-runner.lock

# Links the published package to this repository, which is what makes it PUBLIC: a GHCR
# package with no associated repository is created private, and the fleet's 62 public
# repositories then cannot pull the image their gate runs in.
LABEL org.opencontainers.image.source=https://github.com/portable-genai/.github

COPY run-grc-ci /usr/local/bin/run-grc-ci
RUN chmod 0555 /usr/local/bin/run-grc-ci \
    && useradd --create-home --uid 10001 ci

USER ci
ENTRYPOINT ["/usr/local/bin/run-grc-ci"]

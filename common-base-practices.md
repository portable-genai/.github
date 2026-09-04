---
type: Engineering Standard
title: Common-base practices catalogue
description: Checkable architecture, security, delivery, evaluation, demonstration and adoption practices for catalog repositories.
tags: [practices, audit, architecture, security, delivery, quality]
status: stable
---

# Common-base practices catalogue (checkable in any catalog repo)

This is the generalised list of policies and engineering practices the reference build
`cdd-sow-research` follows, written so any repo in the catalog can be
audited against it. Each practice
states: what it is, why it matters, the mechanism in the reference repo (evidence), and
**Check**: a concrete command or inspection another repo can run. "PASS" means the check
holds with that repo's own names substituted.

**Evidence paths** in the "Here:" lines below are relative to the reference repo
`cdd-sow-research/` (a sibling folder of this catalog in the polyrepo workspace), e.g.
`domain/gap_analysis.py` means
[`../cdd-sow-research/src/cdd_sow_research/domain/gap_analysis.py`](../cdd-sow-research/).
When auditing another repo, substitute that repo's package/paths.

Companion catalogues live in the reference repo:
[`../cdd-sow-research/ARCHITECTURE.md`](../cdd-sow-research/ARCHITECTURE.md) §6
(portability PT-1..PT-14) and §7 (security SC-1..SC-17) state the architectural
principles; this file is broader (delivery, supply chain, demo, docs, adoption) and
phrased as audit checks. Reusable build skills that automate several of these patterns in
a new repo live under `cdd-sow-research/.agents/skills/`.

Legend for applicability: **[all]** every repo; **[agentic]** repos with an LLM/agent
runtime; **[ui]** repos shipping a web UI; **[infra]** repos shipping Terraform/deploy.

---

## A. Architecture

**A1. Hexagonal core: the domain imports nothing but the standard library.** [all]
Business logic must not import cloud SDKs or frameworks; everything external is a typed
port. This is what makes profiles, portability and offline CI possible.
Here: `src/cdd_sow_research/domain/` (pure stdlib), enforced by convention + review.
**Check:** `grep -rE "google|fastapi|httpx|pydantic|boto3|azure" <pkg>/domain/ --include="*.py" | grep -v "^\s*#"` returns nothing.

**A2. Ports are `@runtime_checkable` `typing.Protocol`s, one file each, re-exported once.** [all]
Here: `src/cdd_sow_research/ports/` (18 ports), re-exported from `ports/__init__.py`.
**Check:** every class under `ports/` has the `@runtime_checkable` decorator; a
contract test asserts it (see A6).

**A3. Swappable runtime/data adapter profiles selected explicitly.** [all]
At minimum: a managed-cloud profile, a WORKING offline profile (not mocks: a real
SQLite/in-process stack), a platform profile with thin HTTP delegates for shared-service
runtime/data ports and explicit reviewed bindings for every other runtime/data port, and a fail-fast sovereign/on-prem
placeholder profile. Switching profiles changes zero domain code. Missing bindings fail
closed; no profile silently inherits another profile's adapter. Identity ports are selected
from an independent exact identity map. Identity and channel must not silently change the
runtime/data profile.
Here: `CDD_PROFILE` = `local | live | gcp | platform | onprem`; bindings under `adapters:` in
`config/settings.yaml` as dotted `module:Class` paths.
**Check:** the settings file has a per-port, per-profile adapter map; running the test
suite with the offline profile needs no cloud SDK installed (`pip install -e ".[dev]"`
only) and passes.

**A4. One adapter constructor convention: `Adapter(settings)`.** [all]
A single positional settings object is the whole build contract, so the DI container can
instantiate any adapter from a dotted path.
Here: enforced by `tests/contract/test_port_parity.py::test_adapter_constructs_with_single_settings_arg`.
**Check:** the contract test exists and parametrises over every port x offline profiles.

**A5. Lazy cloud imports in cloud adapters.** [all]
Every managed-SDK import lives inside a method/`__init__` or `TYPE_CHECKING`, never at
module top level, so offline profiles can import every module.
Here: `adapters/gcp/*`, `agent/*`; proven by the offline test run itself.
**Check:** `grep -n "^from google\|^import google" <pkg>/adapters/gcp/*.py` returns
nothing (imports are indented), and the offline test leg imports all modules.

**A6. Contract tests enforce the hexagon, and the port list cannot silently drift.** [all]
Structural parity (every offline adapter satisfies its Protocol, constructs with one
settings arg) plus a set-equality assertion between the hand-maintained port map and the
settings bindings, so an unregistered port fails loudly.
Here: `tests/contract/test_port_parity.py` incl.
`test_port_protocols_matches_settings_adapters`; behavioral parity in
`test_behavioral_parity.py` (same request through in-process, HTTP-delegate and
placeholder adapters).
**Check:** both contract test files exist; deleting a port binding from settings makes
the suite fail.

**A7. Kernel vs vertical split inside the domain.** [all]
Vertical-neutral machinery (citations/provenance, LLM envelope, safety verdicts, audit
record, eval report, severity scale) lives in a kernel module a fork never edits; the
product's artifact models live in a vertical module a fork rewrites. Backward-compatible
re-exports keep imports stable.
Here: `domain/kernel.py` vs `domain/models.py` (ARCHITECTURE §1.1).
**Check:** the domain has an explicitly named kernel (or equivalent boundary doc) and
the vertical models import from it, not vice versa.

**A8. Consume the platform horizontals; never re-implement them.** [all]
Guardrail/DLP (`agent-guardrail-gateway`), governed RAG (`enterprise-knowledge-base`),
registry (`agent-registry`), eval gate (`model-quality-gate`), observability/WORM audit
(`agent-observability`) are consumed through ports with thin HTTP delegate
adapters. Offline stand-ins are allowed behind the same port; standalone cloud
integrations must be explicitly scoped to standalone deployments.
Here: `adapters/platform/remote_*.py` (54-117 lines each, marshalling only);
ARCHITECTURE §5 maps each dependency to its port + HTTP contract.
**Check:** for each horizontal concern the repo touches, there is a `platform` binding
whose adapter contains no business logic; grep the repo for a second implementation of a
horizontal's core that is NOT behind a port (that is a finding).

## B. Determinism and the LLM boundary

**B1. The consequential math is deterministic, pure, and replayable; the LLM only
narrates, drafts and classifies.** [agentic]
Scores, reconciliations, eligibility, escalation: pure stdlib functions of their inputs,
unit-tested, recomputable by an auditor without the model.
Here: `domain/gap_analysis.py`, `scorecard_service.py`, `source_of_funds_service.py`,
`periodic_review_service.py`, `screening.py`; the LLM writes narrative/RFI wording only.
**Check:** identify every numeric decision the product makes and confirm it is produced
by a pure function with a unit test, not parsed out of model output.

**B2. Every generated claim carries a citation with source and locator.** [agentic]
Here: `Citation` (source id, type, title, page) on every dossier statement; grounding is
retrieve-then-cite (`domain/_grounded.py`); empty retrieval is a hard error, never an
ungrounded answer.
**Check:** the output models have a citation field on claim-bearing types, and the
orchestrator raises (not degrades) when retrieval returns nothing.

**B3. Maker-checker on every consequential output; escalation only raises the bar.** [agentic]
Outputs always set `requires_human_review=True`; hard signals escalate to enhanced
review; nothing auto-executes.
Here: `domain/review_policy.py`; audit decision `ESCALATED` vs `ALLOWED`.
**Check:** grep the output assembly for the review flag defaulting to true and a test
asserting it cannot be produced false.

**B4. Bank-owned policy numbers live in config, not code, with defaults equal to the
reference constants.** [all]
Weights, tolerances, cadences, country lists, escalation bands: frozen dataclasses
parsed from a `policy:` settings section, threaded into engines via `from_policy`
constructors. A test proves defaults reproduce reference behavior AND that an override
changes behavior.
Here: `domain/policy.py`, `config/settings.yaml` `policy:`, `tests/unit/test_risk_policy.py`.
**Check:** pick any tunable number in the repo's engines; confirm it is reachable from
the settings file and covered by an override test. Module-level numeric constants that a
compliance function would want to tune are findings.

**B5. Open taxonomy axis: category vocabularies are `StrEnum`s and engines are typed on
`str`.** [all]
A deployment extends the vocabulary through config/policy tables without editing engine
code; serialized values are the enum strings either way.
Here: `WealthSourceKind`/`FundsOriginKind`/`DocType` as `StrEnum`; engines keyed on
`str`; test `test_engine_accepts_extended_taxonomy_kind`.
**Check:** adding a new category value via config exercises the engine without a code
change (there is a test proving it).

## C. Security

**C1. Identity is resolved server-side; client-asserted actor/ACL is discarded.** [all]
Request schemas carry no actor field; a verified Principal (from the identity port)
supplies the audit actor and entitlement principals.
Here: `api/security.py`, `domain/identity.py`; schemas documented "no actor field".
**Check:** `grep -rn "actor" <pkg>/api/schemas.py` shows no client-supplied actor; the
identity resolution is a server-side dependency on every route.

**C2. Object-level authorization is derived server-side, with tenant isolation
enforced by data tags.** [all]
The resource-scope principal (`case:<id>` etc.) is granted only after an entitlement
check against the verified principal; stored evidence carries BOTH resource and tenant
tags; retrieval matching is subset (all-of) and fail-closed (empty principals see only
untagged public data). Every backend adapter enforces the same documented contract.
Here: `domain/entitlements.py`, `CddService._acl_tags`, the ACL contract on
`ports/knowledge_base.py`, subset `_acl_ok` in both local and gcp KB adapters; test:
cross-tenant persona gets zero passages.
**Check:** the ACL contract is written on the port docstring; each adapter's matcher is
subset/fail-closed; a cross-tenant test exists and passes.

**C3. Redact before everything.** [agentic]
PII is de-identified at the boundary before any model, index, registry, trace or audit
call; audit stores already-redacted text only.
Here: first step of `CddService.assess`; `AuditEvent.redacted_prompt/response`.
**Check:** trace the orchestrator: no raw input reaches an outbound port before the
redaction call; audit fields are named `redacted_*`.

**C4. Jurisdiction-driven PII packs keep the safety gate honest.** [agentic]
National-identifier patterns are selected by configured jurisdiction, used by BOTH the
runtime redactor and the eval `pii_safety` metric, so a non-home-jurisdiction fork does
not inherit a falsely green gate.
Here: `domain/pii_patterns.py` (SG/IN/GB/HK/ID/MY/AU), `pii.jurisdictions` setting,
`CDD_PII_JURISDICTIONS` for the gate; `tests/unit/test_pii_jurisdictions.py`.
**Check:** the PII patterns are config-selected, and a test shows the home-jurisdiction
pack does NOT mask another jurisdiction's identifiers (the false-green proof).

**C5. Fail-closed defaults everywhere.** [all]
No-auth dev identity binds loopback only (explicit env override to expose); CORS has no
cross-origin trust in secure profiles unless configured; dev-only headers are
dev-profile-only; unknown/missing config refuses rather than guesses.
Here: `api/app.py` `main()` guard + `CDD_ALLOW_INSECURE_DEMO`; `_cors_origins()` profile
gating; Makefile `API_HOST ?= 127.0.0.1`.
**Check:** run the API with no env under the dev profile: it binds loopback; unset the
CORS allowlist under a secure profile: no origins are trusted.

**C6. Security-header baseline on every surface.** [ui]
API: CSP frame-ancestors, nosniff, Referrer-Policy, HSTS on secure profiles. UI: full
CSP (default-src 'self', scoped connect-src), nosniff, Referrer-Policy, frame-ancestors.
Here: `api/app.py` middleware; the UI's own policy module.
**Check:** curl any endpoint and inspect headers; read the UI policy module for the CSP block.

**C6a. The UI CSP must be nonce-based, and the page must be able to CARRY the nonce.** [ui]
`script-src 'self'` is not a safe default for a Next console: the framework serves its
hydration bootstrap as an INLINE script, so a bare `'self'` blocks it, React never attaches
and the page ships as dead markup. The nonce alone is not the fix either. Three things must
agree: the policy module emits `'nonce-<n>' 'strict-dynamic'`, the proxy puts that policy on
the REQUEST `Content-Security-Policy` header (the only name the framework reads a nonce
from), and the route is dynamically rendered, because a prerendered page was built before the
nonce existed. Getting two of the three is WORSE than the bare policy above, since
`'strict-dynamic'` disables the `'self'` fallback that at least loads the chunk scripts.
Emit the policy from ONE layer: two layers both setting it hands the browser two policies to
intersect, and the stricter one wins.
Here: the UI policy module, `proxy.ts`, `app/layout.tsx` (`force-dynamic`), and the
`assertHydratableCsp` build refusal.
**Check:** `npm run assert-hydratable` against a production build, which starts the server and
asserts every script tag in the served document carries the served nonce. Header assertions,
type-checks and screenshots all pass while this is broken, so none of them is the check.

**D1a. `make lock` must not be able to destroy the lockfile header.** [all]
`uv pip compile` REPLACES its output file: it writes a two-line provenance comment and nothing
else, so a bare call destroys the header block, including the `tag = commit` map the pin tests
check the three-way agreement against. That is not hypothetical; one repo shipped it and carried a
red gate. The `lock` target runs `scripts/lock.py`, which compiles and re-applies the header,
deriving the map from the tags `pyproject.toml` declares and the commits the compiled body
actually pins, so the map cannot drift from the file it describes.
Here: `scripts/lock.py`, the `lock` Makefile target.
**Check:** run `make lock` and confirm the file still starts with the header and still carries the
map; and confirm the Makefile target does not call `uv pip compile` directly.

**C6b. Tracing and structured logging are bound ports and a shared formatter, not per-repo code.** [all]
The tracer Protocol and `TokenUsage` come from `hex_service_kit.observability`, the evaluation
gate from `agent_eval_kit`, and each repo RE-EXPORTS them from `ports/observability.py` rather
than declaring them. The repos that hand-copied these first had already drifted: one lost the
evaluation port, two lost its `gate` method, one changed a return type. Where spans go is
deployment configuration, never a profile: `OTEL_EXPORTER_OTLP_ENDPOINT` set means OTLP to the
`agent-observability` collector, unset means direct Cloud Trace, EMPTIED refuses. Span attributes are structural
only; a span is not a redacted sink. Tracing is the one seam that is ABSENT rather than fatal
on-prem and the one managed adapter that must NOT refuse offline, because an exporter fault must
never become a request fault; declare that exemption and assert it in both directions.
`configure_logging` runs at module scope in `api/app.py` and at the top of the CLI: JSON with
Cloud Logging's field names and the active trace id on a deployed profile, plain text offline.
Here: `ports/observability.py`, `adapters/{local,gcp,onprem}/{tracer,evaluation}.py`.
**Check:** bind each profile and open a span (all three must complete, none may raise); call
`gate` on local and onprem (both must refuse); format a record carrying an unexpected `extra`
and assert it is DROPPED, since logs are not WORM and nothing redacts them downstream.

**C7. Service-to-service calls are authenticated and https-only outside loopback.** [all]
Platform delegates attach a bearer credential, refuse plaintext non-loopback base URLs
at construction, and propagate the verified end-user as a signed header, never a bare
JSON field.
Here: `adapters/platform/_s2s.py` used by every remote adapter.
**Check:** construct a platform adapter with `http://internal-host`: it raises; grep for
`httpx.post(` in platform adapters: every call site passes the shared auth headers.

**C8. Web login flow hardening (when the repo owns a login).** [ui]
Authorization Code + PKCE (S256), signed state AND nonce verified constant-time, JWKS
verification with an explicit algorithm allowlist, `__Host-`/`__Secure-` cookie
prefixes, session key rotation via accepted-key list, https-only issuers, open-redirect
clamping, and deletions that carry the same cookie attributes as the set.
Here: `api/auth.py`, `adapters/oidc/*`; tests in `test_oidc_auth_flow.py`.
**Check:** the OIDC test file covers: state mismatch, nonce mismatch, alg=none, wrong
audience, JWKS failure, open-redirect attempts, rotation, and logout cookie deletion
asserting the Secure attribute.

**C9. Tamper-evident audit with honest limits.** [all]
Offline/on-prem audit is hash-chained over canonical JSON, append-only enforced in the
store (triggers), with an external head anchor for truncation detection, open-format
export/restore that re-verifies every link, and a docstring stating exactly which tamper
classes are and are not detected. Managed profiles use a locked WORM bucket.
Here: `adapters/local/audit.py`; `cdd-sow audit verify|export|restore`.
**Check:** the audit module documents its threat coverage; a test doctors a record and
verify catches it; a test truncates the tail and the anchor catches it.

**C10. No secret values in the repo; config names env vars, never stores secrets.** [all]
Here: `config/settings.yaml` stores only `*_env` names; values read at construction and
never logged.
**Check:** `grep -riE "secret|token|key" config/ | grep -v "_env\|ENV\|name"` finds no
literal secret material; a secret scanner over the repo is clean.

## D. Supply chain and CI

**D1. Locked, reproducible dependency installs everywhere.** [all]
Committed lockfiles compiled from the project file; CI and the container image install
from the lock (`--no-deps` for the project itself); formatter pinned exactly.
Here: `requirements-dev.lock`, `requirements-dev-oidc.lock`, `requirements-gcp.lock`;
Dockerfile installs from the gcp lock; `ruff==` exact pin.
**Check:** the lockfiles exist, CI installs `-r <lock>` not open ranges, and the
Dockerfile does not `pip install "<pkg>[extra]"` unlocked.

**D2. Digest-pinned base images; SHA-pinned GitHub Actions; dependabot on every
ecosystem; dependency audit in CI.** [all]
Here: `FROM python:3.14-slim@sha256:...`; `.github/dependabot.yml` (pip, npm, docker); the
hosted GitHub Actions check running `pip-audit` on the lockfiles + `npm audit --audit-level=high`.
Actions themselves are pinned by 40-character commit, never by tag, and the organization enforces
that with `sha_pinning_required` rather than trusting each author: a tag is a movable pointer, so
a pinned tag is an unpinned dependency wearing a version number.
**Check:** `grep -n "FROM .*@sha256" Dockerfile`; the dependabot file lists every ecosystem the
repo actually pins; the repo appears in `org-metadata/ci/gcp/repository-policy.json`, without
which it has no gate at all.

**D3. The whole gate runs offline with zero org secrets, so a fork's CI is green on
day one.** [all]
Lint + format check + typecheck + unit/contract tests + the eval smoke check, all under
the offline profile.
Here: the hosted GitHub Actions check runs `make gate`, which contains the eval, under
`CDD_PROFILE: local` with no secrets.
**Check:** clone the repo into a clean environment with no credentials and no network, and
`make gate` passes unmodified.

**D4. Non-root, minimal, healthchecked container.** [infra]
Multi-stage build, venv copied into slim runtime, dedicated uid, EXPOSE + HEALTHCHECK,
secure profile selected explicitly by env in the image.
Here: `Dockerfile` (uid 10001, healthcheck against `/healthz`, `CDD_PROFILE=gcp`).
**Check:** `grep -n "USER\|HEALTHCHECK" Dockerfile` shows both; the runtime stage
contains no build toolchain.

**D5. Deploy-time enforcement of residency and sovereignty, parameterised not forked.** [infra]
Region pinned and validated fail-fast; Org Policy resource-location allowlist; CMEK with
explicit per-service bindings; VPC-SC dry-run-first; WORM log bucket with retention; a
second enterprise/region is a tfvars file, never a repo fork; Terraform fmt+validate in
CI with no cloud credentials.
Here: `infra/terraform/*`, ci.yaml terraform job, ARCHITECTURE PT-13.
**Check:** CI validates Terraform offline; region/tenant appear only as variables.

## E. Quality gates and evals

**E1. A deterministic offline eval smoke check guards every merge; the platform eval
service `model-quality-gate` is the promotion authority.** [agentic]
Golden dataset + metric scorers run in CI offline; the authoritative promotion verdict
comes from the shared eval platform through the evaluation port at release time. The
in-repo harness is labelled a smoke check, not the gate of record.
Here: `eval/run_eval.py` + `eval/datasets/` + `eval/rubrics/` (smoke);
`EvaluationGatePort` -> `model-quality-gate` (promotion).
**Check:** CI runs the offline eval on every PR; the repo documents which authority owns
promotion; metric thresholds are not duplicated as unlabelled constants.

**E2. A safety metric with the strictest threshold, structurally unable to go falsely
green.** [agentic]
Here: `pii_safety >= 0.99`, detection patterns shared with the runtime redactor and
jurisdiction-configurable (see C4).
**Check:** the gate's PII detector and the runtime redactor read the same pattern
source.

**E3. Fixtures and golden data are obviously fictional.** [all]
Here: "Acme Holdings Pte Ltd (FICTIONAL)", fake NRICs, a fictional sanctions snapshot;
stated in DEMO.md/COMPLIANCE.md with a live-data sign-off warning.
**Check:** sample the fixtures; every name/id is unmistakably synthetic and the docs
carry the warning.

**E4. The promotion verdict fails closed when nothing was evaluated.** [agentic]
`all(())` is vacuously `True`, so `all(r.passed for r in self.results)` reports PASSED for a
report carrying no results, and `eval/run_eval.py` exits `0` on that property: an evaluation
that measured nothing certifies a promotion. Every hand-copy repo carried its own copy of
this, and pinning a fixed `agent-eval-kit` did not reach any of them, because the platform
adapter maps the package report onto the repo's own domain `EvalReport` and the hardened
verdict is discarded at that boundary. The count is therefore load bearing: an adapter that
hardcodes `n_examples=0` either fails every real evaluation or, before the fix, passed on no
evidence at all. The same applies to an offline adapter's missing-evaluator fallback, which
must return an empty report rather than a hand-written passing metric: `gate()` is
`evaluate("").passed`, so a fabricated pass approves precisely when the evaluator is absent.
Here: `passed` requires `n_examples > 0` and a non-empty `results`; cloud adapters report the
examples they submitted; `EvalReport(dataset=..., results=(), n_examples=0)` is the honest
"nothing was evaluated" value.
**Check:** `scripts/portfolio-status.sh` section 6 scans every repo for both shapes; a repo
also carries a unit test that was proven red against the vacuous form before it went green.


**D1a-i. A guard must not be able to cause the damage it guards against.** [all]
`scripts/lock.py` exists because `uv pip compile` destroys the lockfile header. Its own checks
ran AFTER the compile, so an abort returned non-zero and left a compiled headerless lockfile:
the exact state it prevents, and worse than no guard because the failure looked handled. It also
built the header map from every extra at once, so a commons pinned only in the dev extra read as
missing from a lockfile it is legitimately absent from, which is how the abort fired for real.
Here: the file is snapshotted before the compile and restored on any abort; tags are scoped to
the core dependencies plus the one extra each lockfile is compiled with.
**Check:** simulate the abort (a compile that pins no commons) and assert the file comes back
byte-identical, not merely that the exit code is non-zero.

**D1a-ii. Verify a bumped pin against the tag, never against the exit code.** [all]
`uv pip compile` can serve a CACHED git resolution: a bumped tag in `pyproject.toml` recompiles
to a success exit and a plausible lockfile still pinning the previous commit.
**Check:** compare the resolved 40-character commit against `git rev-list -n 1 <tag>` after every
relock; a green command is not evidence.

**E5. Run the repo's OWN gate command, not an approximation of it.** [all]
A repo's `make gate` / `make test` may export what the suite needs, most often
`<PREFIX>_PROFILE=local`, because an unnamed profile is deliberately refused (see C: the
exposure split). A bare `pytest` therefore reports failures that do not exist, and running it
from the workspace root instead of the repo changes rootdir and config discovery and reports
far more. Both mistakes look exactly like a broken repo. This is not hypothetical: it produced
two separate false reports of fleet-wide breakage in one session, one of them a claimed 40
failing tests in a repo whose own command was green at 928 passed.
**Check:** before reporting any repo as red, re-run the exact recipe in its `Makefile` from
inside the repo, and quote that command alongside the result.

## F. Demo and anti-rot

**F1. The demo is code, runs offline, one command, presenter-paced.** [all]
A scripted walkthrough drives the REAL services (not canned screenshots), starts its own
server, narrates on the presenter's console (never the product UI), and supports
back/jump.
Here: `make demo` -> `scripts/sow_demo_playwright.py` + `scripts/sow_demo_server.py`
(real `SowCaseService`, 10 steps).
**Check:** one documented command starts the full demo on a laptop with no cloud and no
API key.

**F2. The demo cannot rot silently.** [all]
A headless unattended self-test asserts each step's LIVE state (figures read from the
running app, not hard-coded prose) and runs in CI; a browserless test covers the
server/renderer path; demo tooling is a pinned extra; UI panels expose stable
`data-*` hooks instead of styling-coupled selectors.
Here: `make demo-selftest` in ci.yaml; `tests/unit/test_demo_server.py`; `[demo]` extra
pinning Playwright; `data-panel` attributes in `scripts/render_sow_ui.py`.
**Check:** grep CI for the demo self-test job; break a demo step locally and confirm the
self-test exits non-zero.

**F3. Each portability claim is executable and bounded.** [all]
One offline script gates the portability properties the repository currently implements,
such as a runtime-profile seam, complete port parity, tamper evidence, open-format
export/reload, or a real identity path. It must not relabel a printed binding as an
identity swap, a fail-fast placeholder as a working migration, or an audit-only round trip
as full data exit.
Here: `scripts/portability_demo.py` (DEMO.md §4).
**Check:** the script exists, runs offline, asserts map completeness, and its exit code
gates every named claim; documentation states the unproved dimensions.

**F4. Local and GCP are two profiles of one product, proved as a pair.** [UI]
The same UI route, API schema, deterministic business artifact and evidence relationship run on
loopback and at a reviewed hosted HTTPS origin. Local stays functional but names every reduction
in model/OCR quality, scale, identity, managed controls, durability and performance. The hosted
run uses immutable images and production-profile adapters. Local execution, Terraform validation,
plan, apply and target-browser evidence are never conflated.
Here: [`docs/portable-production-design.md`](docs/portable-production-design.md).
**Check:** the walkthrough accepts loopback or exact HTTPS origins; the profile/region is visible;
the same consequential figures and citations can be compared; documentation states which cloud
evidence actually exists.

## G. Documentation and adoption

**G1. A declared documentation authority order, kept true.** [all]
Spec (locked decisions) > architecture (ports, sequences) > compliance (principle to
control map) > README, with staleness treated as a bug (a shipped feature must not be
described as "forthcoming").
Here: AGENTS.md declares the order; SPEC §9 updated when the feature shipped.
**Check:** read the spec's "forthcoming/not built" sections against the code; any
shipped feature still marked unbuilt is a finding.

**G2. Compliance is a mapping table with evidence pointers, plus an adopter-owned
regulator crosswalk.** [all]
Every internal principle maps to a concrete control with file references; a per-regulator
appendix (home regulator filled in as the template) is explicitly adopter-owned.
Here: `COMPLIANCE.md` P-01..P-13/R1..R8 + MAS 626 crosswalk appendix.
**Check:** each mapping row names files that exist; the crosswalk states who owns it.

**G3. A documented, mechanised fork path.** [all]
An ADOPTING guide with the kernel/vertical boundary, a core-vs-adopter-owned file list,
a one-pass rename script (package, CLI, env prefix, resource ids; dry-run first), and a
checklist of the human decisions (region, IdP, PII pack, policy, fixtures, eval golden
set).
Here: `docs/ADOPTING.md`, `scripts/rename_fork.py`.
**Check:** run the rename script with `--dry-run` in a scratch clone; then apply and the
gate passes.

**G4. Retired.** Repositories carry no changelog. A hand-maintained release narrative
duplicates what git tags and the `pyproject.toml` version already state, and the two
drift the moment anyone forgets one of them. Track releases by tag and version bump; the
fork boundary in ADOPTING section 2 is unaffected. The number stays retired rather than
reused, so it is never confused with a check that once meant something else.

**G5. Role-specific FAQs that reference sibling catalog systems instead of duplicating
them.** [all]
Security / portability / features / adoption / compliance FAQs, each stating where this
repo's responsibility ends and which catalog system owns the adjacent concern.
Here: `docs/faq/` (five files + index), each cross-referencing the platform repositories it
depends on by name.
**Check:** the FAQ names the owning repository for every adjacent capability; no FAQ
re-documents a horizontal's feature set.

**G6. Contribution docs cover the FULL extension touch list, enforced by a test.** [all]
"Adding an adapter" AND "adding a new port/sub-service" list every file to touch; the
contract test fails loudly when the list is not followed (see A6).
Here: `CONTRIBUTING.md`; `test_port_protocols_matches_settings_adapters`.
**Check:** follow the doc to add a dummy port in a scratch branch; the test tells you
about every missed step.

**G7. Markdown discipline: minimise em-dashes; validate mermaid before committing.** [all]
Here: an AGENTS.md convention; applied across docs.
**Check:** `grep -c "—" *.md docs/*.md` is at/near zero; mermaid blocks render.

---

## How to run an audit against another repo

1. Copy this file's section headings into a scorecard (A1..G7, ~35 checks).
2. Substitute the repo's package/env names into each **Check** command.
3. Mark each PASS / PARTIAL / FAIL / N-A (using the applicability tags).
4. FAILs on A1-A6, C1-C5, D1-D3 and E1 are the load-bearing ones: they break the
   catalog's shared guarantees (portability, tenancy, supply chain, promotion gating).
   The rest are quality-of-adoption.
5. Record the scorecard in the audited repo (e.g. `docs/practices-audit.md`) and track the
   remaining gaps wherever per-system state is held.

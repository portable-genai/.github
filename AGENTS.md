# AGENTS.md

The working agreement for every repository in this organization. A repository's own
`AGENTS.md` carries what is specific to it: its package paths, its environment prefix, its
ports and the invariants that bind them. Everything below holds everywhere and is not
repeated there.

Read this first, then the repository's own `AGENTS.md`, then its `SPEC.md`.

## The convention for these files

`AGENTS.md` is the working agreement, and it is the only one: no repository here carries a
tool-specific alias of it, so there is no second copy to keep in step. `.agents/skills/`
holds the shared build skills, in the portable Agent Skills location.

The skills under `.agents/skills/` are vendored verbatim. Do not edit them inside a
repository: a repo-local reformat forks them silently. Fix the source and resync.

## Documentation authority

When documents disagree, the later one loses:

`SPEC.md` > `ARCHITECTURE.md` > `COMPLIANCE.md` > `README.md` > demo and FAQ material.

Executable code and its tests outrank all of them, because they are the only evidence of
what actually ships. When the code contradicts a document, the document is wrong and moves
in the same change. A published claim is a test nobody wrote.

## Architecture

Hexagonal, and not decoratively:

- **The domain imports only the standard library.** Business logic lives in a pure core
  reached through typed `@runtime_checkable` `Protocol` ports. No cloud SDK, no web
  framework, no HTTP client, no settings object reaches it.
- **Adapters come in profile families.** `local` runs offline with no credentials, `gcp`
  binds managed services, `onprem` is a sovereign placeholder that fails fast rather than
  pretending, and `platform` delegates to a sibling service over HTTP. Every adapter import
  of a cloud SDK is lazy, inside the method or `__init__`, so the offline profile never
  loads it.
- **One settings file maps port to adapter.** Switching profile changes bindings, never
  domain code. There is no silent fallback to a managed adapter: an unbound port raises.
- **The catalog id is the stable identity.** Repository names describe; ids like `Hrz1` or
  `Doc2` are what documentation and dependency lists key on. The
  [organization front page](https://github.com/portable-genai) resolves every id to its
  repository and lists what each one requires.

## The gate is the contract

`make gate` (or the target the repository's README names) must pass with **no network, no
credentials and no cloud SDK installed**. That is the whole portability claim, reduced to a
command. If a change needs any of those three to pass, the change is in the wrong layer.

Do not push a red gate. Do not read a truncated gate summary and assume the rest was green.

## Invariants

A change that breaks one of these is a defect, not a trade-off. The concrete bindings are in
each repository; the rules are these.

- **Identity is resolved, never accepted.** The server determines the principal and discards
  whatever the client claimed. No request schema carries an actor, a tenant or an
  entitlement.
- **The exposure posture derives from the identity binding, never from a credential.** A
  service credential authenticates a calling service and no end user. Setting one must never
  widen an end-user route.
- **Entitlement filtering is fail-closed.** An empty principal sees untagged public data, not
  everything.
- **Redaction precedes the model, and the audit record stores redacted text.** The guard sits
  where content crosses the boundary, so it holds for every caller rather than at each call
  site. Integrity is not confidentiality: a hash chain protects whatever it is given.
- **Consequential logic is deterministic, pure and replayable.** Scores, eligibility,
  reconciliation and escalation are stdlib-only and testable without a model. The model
  drafts, narrates and classifies. It never owns an outcome, in any profile.
- **Nothing auto-executes.** Every consequential output carries a human-review requirement,
  and escalation only ever raises the bar.
- **Every generated claim is grounded**, with a source and a locator. Empty retrieval is a
  hard error, never an ungrounded answer.
- **Configuration has three states.** Unset, set-and-empty and set-and-valid are
  distinguished. An emptied allowlist must never inherit the permissive unset default, and
  one module owns each read.
- **Embedding controls refuse a wildcard in every spelling**, including the literal `null`.
- **Policy numbers are configuration, not code**, parsed into frozen structures.

## A guard observed only green asserts nothing

Every check here must be shown to **fail against a deliberate defect before it is trusted**.
Write the test, watch it go red, then make it pass. A green result that was never red is
indistinguishable from an absent one, and this organization's own history is a list of guards
that failed that test: a demo profile that authenticated nobody, an evaluation that returned
"passed" over an empty metric list, an audit export whose anchor did not travel, a
wildcard-refusal test that set one variable and read another.

The same rule applies to counts and summaries. A check that reports success over zero items
has not checked anything.

## The shared practice checks

Every repository scores itself against the numbered checks A1 to G7 defined in
[`common-base-practices.md`](common-base-practices.md), and records its verdict in its own
`docs/practices-audit.md`, including the checks it does not pass. When you close a check,
update that file with the evidence, and say what you observed failing first.

## Versions and dependencies

Every repository and every shared package is at `0.0.1`. Consumers pin each shared package
by tag, `@v0.0.1`, in `pyproject.toml`, and the lockfiles pin the commit that tag resolves
to. A tag can be moved; a commit cannot, which is why the lock pins the commit.

Dereference a tag with `git rev-list -n 1 <tag>`, never `git rev-parse <tag>`: these are
annotated tags, so `rev-parse` returns the tag object, and a lockfile pinned to one looks
pinned and does not install.

Provider selections are source-controlled. `.terraform.lock.hcl` is committed, never ignored.

## House style

- **No em-dashes.** Anywhere: prose, docstrings, commit messages.
- **Fictional data only.** No real customer, institution, identifier or credential in
  fixtures, examples, demos or documentation. Never a real home-directory path.
- **Prefer deleting a claim to weakening it.** A hedged sentence nobody can check is worse
  than no sentence.
- **One fact, one home.** Link down to whichever file owns a fact; do not restate it. A
  copied status snapshot is stale the moment the source moves, and nothing notices.

## Where the work is written down

Public, and the golden source for anything stated twice:

| Where | What it owns |
|---|---|
| [The organization front page](https://github.com/portable-genai) | What each repository does, the dependency graph and the rules behind it, the numbered principles |
| [`common-base-practices.md`](common-base-practices.md) | The A1 to G7 check definitions |
| [`SECURITY.md`](SECURITY.md) | Reporting a vulnerability, what is enforced, what assurance does not exist |
| Each repository's `docs/practices-audit.md` | That repository's verdict against the checks |

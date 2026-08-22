# Contributing

This applies to every repository in the organization that does not carry its own
`CONTRIBUTING.md`. Where a repository has one, that file wins, because it names the
package paths and gate targets that are specific to it.

## What this is, before you spend time

These are Apache-2.0 reference implementations, not a product with a roadmap. The most
useful contributions are the ones that make a claim checkable: a failing test for
behaviour that is wrong, a guard that is proven able to fail, a document corrected to
match what the code does.

Forking and taking the code in your own direction is an expected use, not a fallback. You
do not need permission and you do not need to contribute anything back.

## The bar

- **The domain imports only the standard library.** Business logic sits behind typed
  ports. Cloud SDKs, web frameworks and HTTP clients belong in adapters, and their imports
  are lazy so the offline profile never loads them.
- **Consequential logic is deterministic and replayable.** The model narrates, drafts and
  classifies. It never produces the number and never owns the outcome.
- **A new guard must be observed failing before it is believed.** Write the test, watch it
  go red against a deliberate defect, then make it pass. A green result that was never red
  is not evidence.
- **The offline gate is the contract.** `make gate` (or the repository's documented
  equivalent) must pass with no network, no credentials and no cloud SDK installed.
- **Documentation is part of the change.** If a change makes a sentence in the repository
  untrue, the sentence moves in the same commit.

The shared checks every repository is audited against are defined in
[`common-base-practices.md`](common-base-practices.md).

## House style

- No em-dashes.
- Test and demo data is obviously fictional. Never a real customer, institution,
  identifier or credential, in fixtures, examples or documentation.
- Prefer deleting a claim to weakening it. A hedged sentence nobody can check is worse
  than no sentence.

## Pull requests

Keep them small and single-purpose, with the gate green before you open one. Say in the
description what you observed failing, and how, since that is the part a reviewer cannot
reconstruct.

Security issues do not belong in a pull request or a public issue. See
[SECURITY.md](SECURITY.md).

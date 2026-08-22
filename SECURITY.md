# Security policy

## What these repositories are

Apache-2.0 reference implementations of GenAI and agentic systems for regulated
industries. They are published so the architecture can be inspected, forked and operated
by the adopter. There is no vendor, no support tier and no warranty. Nothing here is
operated as a service, so there is no production deployment of ours to attack or to
protect.

## Reporting a vulnerability

Use **GitHub private vulnerability reporting** on the affected repository: open its
**Security** tab and choose **Report a vulnerability**. That keeps the report private
until a fix exists, and it reaches the maintainer without a public issue disclosing the
problem first.

Please include the repository, the profile it reproduces under (`local`, `gcp` or
`onprem`), and the smallest reproduction you have. If a finding depends on a deployment
configuration rather than on this code, say so, because those are the reports most easily
misread in both directions.

Do not open a public issue for a suspected vulnerability, and do not include real
customer data, credentials or production identifiers in a report. Every fixture in these
repositories is deliberately fictional and reports should be too.

**Expect a best-effort response.** This is maintained by one person alongside other work.
There is no committed response window, no service level and no bug bounty. That is stated
plainly rather than implied by silence.

## What is enforced in the code

Each repository states its own posture in `docs/faq/security-faq.md` and records its
verdict against the shared checks in `docs/practices-audit.md`, including the checks it
does not pass. The check definitions are in
[`common-base-practices.md`](common-base-practices.md).

The properties the design holds to, each with tests behind it: the server resolves the
principal and discards any client-asserted identity; retrieval filtering is fail-closed;
redaction runs before any model call and the audit record stores already-redacted text;
consequential logic is deterministic and replayable, and the model never owns an outcome;
every consequential output requires human review; the audit trail is hash-chained with an
integrity witness that travels out of band; and configuration distinguishes unset from
set-and-empty so an emptied allowlist cannot inherit a permissive default.

A guard observed only passing is indistinguishable from a guard that asserts nothing, so
each of those is proven able to fail against a deliberate defect before it is trusted.

## What does not exist

Stated so a reviewer does not have to discover it:

- No third-party penetration test.
- No SOC 2, ISO 27001 or equivalent certification. There is no organisation to certify.
- No formal threat model document. Threats are addressed control by control.
- No published SBOM. Dependencies are pinned and locked, but provenance is not formalised.
- No external code review. Review is by the maintainer and by automated gates.

For a reference implementation these absences are normal. For a production deployment they
are not, and closing them is adopter work that should be budgeted from the start rather
than discovered at a security review.

## Supported versions

Only the default branch of each repository. There are no maintained release branches and
no backports.

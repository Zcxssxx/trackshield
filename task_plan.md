# TrackShield development ledger

## Goal

Create a new, reviewable MoonBit CLI and reusable library that audits collections of GPX exports for repeated-location and metadata exposure, then previews or applies redaction only for a user-specified area.

## Phase status

- [x] Topic selected: TrackShield, multi-activity GPX privacy audit.
- [x] Product design approved in chat.
- [x] Save and self-review the written design specification; user approved it on 2026-10-25.
- [x] Write and self-review the implementation plan; user selected inline execution on 2026-10-25.
- [x] Implement the MoonBit library and CLI, core tests, synthetic collections, documentation, license, and dependency provenance.
- [x] Configure a local MoonBit CI workflow and verify its commands on supported targets.
- [ ] Reconcile the installed MoonBit version with the newest official stable release channel.
- [ ] Complete local submission-readiness review.
- [ ] Only after local completion, check the active GitHub identity and perform explicitly authorized remote work.

## Constraints

- Work only in this new local repository; do not modify neighboring projects.
- Do not access or modify GitHub until local development and verification are complete.
- Use MoonBit as the primary implementation language.
- Use the Git author name Zcxssxx.
- Keep a traceable history with more than ten meaningful commits; do not create empty or mechanically split commits.
- Target at least 3,000 meaningful MoonBit source lines across implementation and tests; add only real capabilities needed by users.
- Never present a heuristic report as proof that a track collection is anonymous or that a location is a home.
- Keep audit read-only. Redaction requires an explicit user-provided zone and writes to a separate destination only after preview.

## Progress pointers

- Product specification: docs/superpowers/specs/2026-10-25-trackshield-design.md
- Implementation plan: docs/superpowers/plans/2026-10-25-trackshield.md
- Research and provenance notes: findings.md
- Session progress: progress.md

## Current gate

- Implementation plan execution is active in the current session on `codex/trackshield-development`. Tasks 1–16 are implemented and independently reviewed. Task 15 added user/API docs, one-cluster synthetic examples, an OSI-approved root license, and exact dependency provenance; all README commands passed. Task 16 added a local CI workflow using the official latest toolchain channel, with a complete native suite and a library-only wasm/wasm-gc/js matrix. Full strict native tests pass 142/142; each portable-library matrix test passes 113/113 and each target builds. YAML parsed with PyYAML 6.0.2. Details are in `.superpowers/sdd/task-15-report.md` and `.superpowers/sdd/task-16-report.md`. The upstream async Windows C4005 `EINVAL` warning remains unsuppressed. Source counters show 4,762 production and 3,633 test MoonBit lines across 41 `.mbt` files; no code was padded to reach the 3,000-line quality target. Continue with Task 17.
- Continue local-only work. Do not configure a GitHub remote, browse authenticated GitHub state, create a repository, push, or claim hosted CI status.
- The October landing page currently reports a 2026-10-31 registration and acceptance deadline. The formal charter and supplemental page have not yet yielded readable contents; unresolved event clauses remain `待确认` in `findings.md`. Local toolchain is `moon 0.1.20261023` / `moonc v0.10.17+d971670cd`; the official newest stable match remains unverified. CI installs the official latest channel and prints its resolved version.

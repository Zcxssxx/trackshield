# TrackShield development ledger

## Goal

Create a new, reviewable MoonBit CLI and reusable library that audits collections of GPX exports for repeated-location and metadata exposure, then previews or applies redaction only for a user-specified area.

## Phase status

- [x] Topic selected: TrackShield, multi-activity GPX privacy audit.
- [x] Product design approved in chat.
- [x] Save and self-review the written design specification; user approved it on 2026-10-25.
- [x] Write and self-review the implementation plan; user selected inline execution on 2026-10-25.
- [ ] Implement library, CLI, tests, examples, documentation, license, provenance, and CI.
- [ ] Verify with the current MoonBit stable toolchain and supported targets.
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

- Implementation plan execution is active in the current session. Task 1 is complete with unresolved official-source requirements explicitly recorded. Task 2's pinned GPX dependency has passing compatibility probes and is consumed by the production adapter. Task 3 is committed (`37bef2f`), Task 4 is committed (`743d79e`), Task 5 is committed (`8aefcb6`), and Task 6's geodesic functions pass their tests. Warning-denial currently reports only five audit/redaction result records awaiting real producers. Task 6 is locally ready to commit.
- Continue local-only work. Do not configure a GitHub remote, browse authenticated GitHub state, create a repository, push, or claim hosted CI status.
- The October landing page currently reports a 2026-10-31 registration and acceptance deadline. The formal charter and supplemental page have not yet yielded readable contents; unresolved event clauses remain `待确认` in `findings.md`.

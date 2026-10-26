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
- [x] Refresh the user-level toolchain through the official default stable channel and compare its result with official release information; record the public release-index lag and the Hackathon-specific rule still awaiting confirmation.
- [x] Complete the local submission-readiness review and prepare an unsubmitted application draft.
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

- Implementation tasks 1–16 and the Task 17 local review are complete on `codex/trackshield-development`. Task 15 added user/API docs, one-cluster synthetic examples, an OSI-approved root license, and dependency provenance. Task 16 added a local-only workflow using the official default stable installer, with strict native checks and a library-only wasm/wasm-gc/js matrix. Fresh Task 17 checks pass native tests 142/142 and each portable-library target 113/113; every requested target builds. Exact prescribed source counting reports 41 tracked `.mbt` files, 4,979 production lines and 3,845 test lines (8,824 total). The history has 27 substantive commits; all recorded author/committer identities are `Zcxssxx`. Detailed evidence is in `.superpowers/sdd/task-15-report.md`, `.superpowers/sdd/task-16-report.md`, and `.superpowers/sdd/task-17-report.md`. The upstream async Windows C4005 `EINVAL` warning remains unsuppressed.
- Continue local-only work. Do not configure a GitHub remote, browse authenticated GitHub state, create a repository, push, or claim hosted CI status.
- The current October landing page reports a 2026-10-31 registration and acceptance deadline; it exposes no update date or exact cutoff time/time zone. The charter and supplement body remain inaccessible through current retrieval, so their clauses stay `待确认` in `findings.md` and `docs/submission-readiness.md`. Local `moon upgrade` on 2026-10-26 completed through the default stable channel and resolved to `moon 0.1.20261023` / `moonc v0.10.17+d971670cd`; CI now invokes the same default stable installer without a development-channel override and logs its resolved version. The public updates index last announces v0.10.14 (2026-09-21), which is recorded as index lag. The Hackathon's exact toolchain clause and hosted workflow run remain pending.
- Local-only stage is complete. Keep the remote stage gated: no GitHub identity check, repository, remote, push, hosted CI, or application submission has been performed.

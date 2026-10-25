# TrackShield development ledger

## Goal

Create a new, reviewable MoonBit CLI and reusable library that audits collections of GPX exports for repeated-location and metadata exposure, then previews or applies redaction only for a user-specified area.

## Phase status

- [x] Topic selected: TrackShield, multi-activity GPX privacy audit.
- [x] Product design approved in chat.
- [ ] Save, self-review, and obtain review of the written design specification.
- [ ] Write and review the implementation plan.
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
- Research and provenance notes: findings.md
- Session progress: progress.md

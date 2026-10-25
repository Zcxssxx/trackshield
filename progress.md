# Progress

## 2026-10-25

- User selected TrackShield after RSS/Atom was excluded by direct Mooncakes overlap.
- User approved the design direction: collection-level audit plus explicit-zone redaction preview; inferred clusters are clues and never trigger automatic deletion.
- Created a separate local repository at this path with branch main and local author name Zcxssxx. No remote is configured and no GitHub operation has been performed.
- Research found 2973181701/moongpx@0.1.0, an Apache-2.0 GPX format library. Its role is distinct from TrackShield; dependency safety and real-world namespace compatibility remain design acceptance gates.
- Wrote the detailed specification and self-reviewed its boundaries, acceptance criteria, error behavior, privacy defaults, dependency gates, and empty-redaction behavior. The staged Markdown passes git diff --cached --check.
- User approved the written design specification and requested the implementation plan.
- Wrote and self-reviewed `docs/superpowers/plans/2026-10-25-trackshield.md`, including 17 implementation tasks, a public API contract, acceptance tests, meaningful commit milestones, local verification, and a final source-count/competition-readiness review.
- Refreshed the October landing-page facts: it reports a 2026-10-31 registration and acceptance deadline, a public-repository submission, a one-page project description, rolling review and revision for rejected submissions, and sustained public development records. The landing page displays no update date. Current web retrieval could not expose the formal charter or supplemental page; detailed license, Mooncakes, CI, and toolchain clauses remain unverified.
- Verified local toolchain output again: `moon 0.1.20261023`, `moonc v0.10.17+d971670cd`, `moonrun 0.1.20261023`. This confirms the installed version only; latest-stable comparison is still an implementation gate.
- `moon new --help` lists `--dry-run`, but the earlier actual `moon new . --dry-run` attempt returned `Error: dry-run is not supported for new`; no scaffold was intentionally created by that attempt. The plan now calls for inspecting a temporary empty-directory scaffold before touching the existing repository contents.
- A plan refinement patch initially missed because its expected test sentence did not match the saved wording; I re-read the exact lines and applied the corrected change. No source implementation or test run was involved.
- At the end of the planning phase, no implementation code or tests had been added and the next step was the user's execution-mode choice; the user then selected inline execution below.

## 2026-10-25 inline implementation, Task 1

- Read `executing-plans`, `using-git-worktrees`, and TDD instructions, and reloaded the approved plan and project ledgers. The user selected inline execution. Confirmed this is a standalone repository and used the requested dedicated project folder; no remote or GitHub action exists.
- Firecrawl CLI is unavailable on this host. The direct browser/web retrieval confirms the official October landing-page facts already logged, but the two Feishu pages still do not expose their contents. Searching the official MoonBit update page for the local toolchain version returned no match; the official download page exposes a “latest” installation channel but not its version number. Stable-version status remains pending.
- A follow-up version-search tool call initially had a JavaScript syntax error; it was corrected and returned no results. No repository files were affected by either search.
- Inspected a fresh temporary MoonBit scaffold. It uses a root package and `cmd/main`, and initializes its own Git repository. The template README symlink failed on Windows with OS error 1314, so this project will create a regular `README.md` later. A first temp cleanup hit Windows access errors; the exact path was verified under `%TEMP%`, force-removed, and its absence confirmed.
- Adapted the plan paths from `src/` to the generated root-package layout. Created `moon.mod`, root `moon.pkg`, `.gitignore`, the root package starter, and `cmd/main` starter without invoking `moon new` in this repository.
- `moon check --deny-warn` passed (6 tasks, up to date). `moon run cmd/main` passed and printed `TrackShield`. No feature tests exist yet; this was a scaffold check.
- Task 1 is ready to commit locally once the plan and progress updates are staged. No GitHub operation or remote configuration has occurred.

## 2026-10-25 continued execution

- User selected inline execution of `docs/superpowers/plans/2026-10-25-trackshield.md`.
- Confirmed the project directory is a standalone local Git repository on `main`, not a submodule or linked worktree; it has no remote and only the design and plan commits. This dedicated new repository is the requested project isolation; no GitHub operation was performed.
- Re-read the execution, worktree, and TDD skills and the approved plan before starting. The project has no MoonBit module yet, so there is no baseline test suite.
- Firecrawl CLI is not installed (`firecrawl` is not recognized). An initial Git isolation probe also encountered an empty-output `.Trim()` error while checking the superproject path; the other outputs confirmed `.git` is both the worktree and common Git directory. Re-run the empty-path check safely and log the confirmed standalone-repository result.
- Task 1 scaffold, plan path correction, and evidence updates were committed locally as `c07d23e feat: scaffold TrackShield MoonBit module`. Formal charter/supplement retrieval and latest-stable toolchain comparison remain pending.
- The first attempt to revise the project ledger used stale text from before the scaffold work; I re-read its current contents and updated the actual current-gate lines. No project source files were affected.
- `moon check --deny-warn` generated root `pkg.generated.mbti`; inspection confirms there are no public values, types, aliases, or traits yet. `_build/` is ignored. Local commit author remains `Zcxssxx <Zcxssxx@users.noreply.github.com>`.
- The first `moon fmt --check` found two manifest-only formatting differences: the formatter spaces `moon.mod` keyword arrays and writes an empty `moon.pkg` as one newline. The initial check returned nonzero while showing those diffs; `moon fmt` normalized them, and a fresh `moon fmt --check` passed.

## 2026-10-25 dependency compatibility gate

- Added the pinned `2973181701/moongpx@0.1.0` dependency to `moon.mod`. The successful local `moon tree --json` resolution is `2973181701/moongpx@0.1.0 -> Milky2018/xml@0.4.1 -> moonbitlang/x@0.5.1`. The license metadata and dependency LICENSE files report Apache-2.0.
- `moon ide doc` remained unavailable after package fetch: queries for `@moongpx.parse_gpx`, `@moongpx.Gpx`, and `Bytes::from_array` all failed with `Fail to load core: no metadata is available for any backend`. I inspected the exact pinned parser/model/serializer sources and compiled tests against the real API instead.
- Added four original inline-fixture tests in `gpx/dependency_probe_test.mbt`. `moon test gpx` exited 0, 4 passed, 0 failed: default-namespace GPX 1.1 round-trip with point extension, GPX 1.0 migration, prefixed-root rejection, and malformed XML rejection.
- `moon test gpx --deny-warn` exited 1 because the compiler reports `unused_package` when a registry dependency is only referenced from test files; `moon check --deny-warn` reports the same. This is a real intermediate warning, not suppressed. Re-run after the production adapter uses moongpx in Task 5.
- XML source inspection found that xml 0.4.1 bounds entity expansion and refuses external entity resolution, but reports DOCTYPE events; the moongpx parser builds a complete tree without a project-specific depth cap. Task 4 now explicitly owns preflight DOCTYPE rejection, nesting and element-count caps, and malformed-input tests before the dependency is ever called.
- The plan now records the actual namespace boundary: default namespace supported; prefixed element names rejected and to be surfaced as a stable TrackShield diagnostic. Extension semantic round-trip is proven only for the authored synthetic fixture; vendor extension compatibility is not yet generalized.
- No GitHub repositories, authentication state, remotes, or hosted CI were accessed.

## 2026-10-25 model and public API work

- Began Task 3 with failing tests for geographic/radius validation, non-finite doubles, XML/resource ceilings, defaults, redaction option copying, and privacy-safe diagnostic rendering. Implemented readonly model structs, public enum constructors, stable diagnostic codes, validated constructors, and the `api` package re-export surface.
- MoonBit external-package tests must qualify local package references (for example `@model.make_geo_point`); the compiler reported `test_unqualified_package` when tests used unqualified names. Public enum constructors use `pub(all)` in the defining package; API callers select variants through the re-exported type, such as `@api.MetadataCategory::TrackName`.
- The official package/access-control docs describe `pub struct` as readonly from other packages while `pub(all)` permits construction; this matches the model's intent to expose fields for reading while forcing geographic/options values through validation. Package functions are publicly re-exported with `pub using`.
- `moon test model` exited 0 with 10/10 tests passed. `moon test api` exited 0 with 1/1 test passed, including construction of `GpxInput` and a redaction option through the public facade.
- `moon info --package api` and `moon info --package model` exited 0 and generated package interfaces. They currently emit eight `struct_never_constructed` warnings for the result records that parser, audit, and redaction implementations have not yet produced. `moon test api --deny-warn` also fails on those same warnings; this is recorded and will be rerun after the planned producer implementations rather than hidden with dummy constructors.
- Full module `moon check --deny-warn` remains deferred until the GPX adapter consumes the pinned dependency and the result-record producers exist. No operational parser/audit/redaction stubs have been added.

## 2026-10-25 XML preflight work

- Implemented `internal/xmlguard` with bounded byte checks, UTF-8/XML declaration validation, lexical DOCTYPE rejection, root/namespace/version checks, XML tag nesting validation, and configurable depth/element caps. It does not open external resources and diagnostics do not echo input content.
- Added 13 XML guard tests for byte-size boundaries; real DTD versus comment/CDATA/quoted text; UTF-8 BOM, malformed byte sequences and declarations; malformed roots/tags; namespace/version handling; prefixed core elements and extension payloads; and depth/element boundaries.
- `moon fmt --check` passed. `moon test internal/xmlguard` passed 13/13; `moon test gpx` passed 4/4; `moon test model` passed 10/10; `moon test api` passed 1/1. `moon info --package model` and `moon info --package api` exited 0 and regenerated interfaces, each reporting the same eight planned result-record warnings.
- `moon test internal/xmlguard --deny-warn` exited 1 on those eight `struct_never_constructed` warnings. `moon check --deny-warn` exited 1 on those eight plus `unused_package` for `2973181701/moongpx`; the production adapter will consume that dependency in Task 5. No warning was suppressed.
- The scanner is not yet on a public parse path because `inspect_gpx` is introduced with Task 5. The next task must run `validate_input` before dependency parsing and add a test proving rejected input does not reach the parser.
- Corrected the authored GPX 1.0 compatibility fixture to use the official Topografix 1.0 namespace URI; the pinned dependency probes still pass 4/4.

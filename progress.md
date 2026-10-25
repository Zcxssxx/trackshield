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

## 2026-10-25 GPX inspection work

- Added public `api.inspect_gpx` backed by the pinned `moongpx` adapter. The XML byte/encoding/namespace/DTD/element/point preflight runs before `parse_gpx_any`; UTF-8 decoding uses the core `encoding/utf8` package and safely removes a validated BOM.
- Added a stable `input.point_limit_exceeded` diagnostic and moved the point-count boundary into lexical preflight, so point-limit failures also happen before the dependency parser allocates its GPX model. The adapter repeats the count after parse as a defensive check.
- Extracted track start/end observations from the first point of the first non-empty segment and last point of the last non-empty segment; empty segments/tracks are tolerated, routes do not create endpoint observations, and each file retains a single source path. Track ordinals are 1-based; observation indexes are 0-based and file-local.
- Extracted safe metadata findings for GPX creator, metadata fields, author identity presence, links, track/route/waypoint labels and descriptions, point timestamps, and extension presence. Findings contain categories and ordinals only; parser diagnostics are replaced with a static message so values cannot leak.
- API tests cover GPX 1.0/1.1, multiple tracks and segments, empty segments and tracks, routes/waypoints without track endpoints, point-limit exact/over boundaries, mixed namespaces, DTD/oversize preflight short-circuit, malformed XML and semantic failures, BOM handling, metadata categories, and stable ordinals. All authored tests pass: xmlguard 14/14, gpx 5/5, model 10/10, api 10/10; full `moon test` passes 39/39.
- `moon info --package model` and `moon info --package api` exit 0. `moon test gpx --deny-warn`, `moon test api --deny-warn`, and `moon check --deny-warn` still exit 1 on five planned result types (`EndpointEvidence`, `RepeatedLocation`, `AuditReport`, `RedactionPreview`, `RedactedFile`) that are produced only by later audit/redaction tasks. The former unused GPX dependency warning is resolved.

## 2026-10-25 geographic calculations

- Added `geo.distance_m`, `geo.spherical_mean`, and `geo.max_distance_from_center`, and re-exported them through the public `api` package. Distances use a 6,371,008.8 m mean Earth radius and shortest-path longitude deltas; the center uses a normalized 3D vector sum.
- Empty/antipodal/near-zero resultant sets return the stable `geo.undefined_center` diagnostic. Exact polar centers use longitude zero. Runtime radius comparison stays inclusive (`distance <= radius`) with no epsilon; fixed-reference tests use a single 0.01 m absolute tolerance.
- Geometry tests cover identity, short equatorial and high-latitude distances, antimeridian crossing, poles, symmetry/non-negativity, threshold values at `r ± 0.01 m`, identical/antimeridian/high-latitude means, antipodal instability, and maximum radius.
- `moon test geo` passes 11/11; full `moon test` passes 50/50. `moon fmt --check`, ordinary `moon check`, and `moon build --target native` pass. `moon test geo --deny-warn` and `moon check --deny-warn` report only five future audit/redaction result-record warnings, with no geometry warning.

## 2026-10-25 inline implementation, Task 7

- Started with red audit tests for support thresholds, duplicate source paths, track counting, transitive chains, exact-radius inclusion, empty collections, and deterministic reordering. The first run failed because the collection API did not yet exist; all 11 audit tests now pass.
- Implemented a deterministic 3D Earth-centered bucket index, exact geodesic edge checks, union-find connected components, stable evidence sorting and IDs, per-file/per-track distinct counts, safe diagnostics, and the public `api.audit_collection` facade. Endpoint evidence paths are normalized from `FileInspection.source_path`, the caller-visible source identity; coordinates never enter evidence records.
- A first chain fixture had three adjacent gaps but only a 889 m total span, so the 500 m-radius center spread correctly stayed below the warning threshold. Expanded it to four 0.004-degree steps (about 1.33 km total); the test now verifies the wider transitive component and warning.
- Review found the configured max radius can be slightly greater than π times the mean Earth radius. The spatial bucket chord calculation now clamps its central angle at π, so all globe-spanning pairs remain candidates; the maximum-radius test confirms an antipodal pair joins. A small bucket-width margin protects exact-boundary candidate discovery while the final distance comparison remains exact and inclusive.
- Refined the result model for undefined spherical means: the maximum-center-distance field is optional; an unstable component emits `geo.undefined_center`, leaves the distance absent, and is not falsely classified as wide. The approved specification and plan now state this behavior. `GeoPoint` validation prevents invalid coordinates entering analyzed inspections; the test covers an unanalyzed file preserving its stable invalid-coordinate diagnostic.
- Final native verification: `moon fmt --check` passed; ordinary `moon check` passed with exactly two known `struct_never_constructed` warnings for the future redaction outputs; `moon test` passed 62/62; `moon build --target native` passed; `moon info --package audit`, `api`, and `model` exited 0 and refreshed interfaces.
- `moon test audit --deny-warn`, `moon test --deny-warn`, and `moon test geo --deny-warn` still fail only on the same two future redaction records, `RedactionPreview` and `RedactedFile`; no audit, geometry, or API warning remains.
- Committed Task 7 locally as `e8c486f feat: find repeated endpoints across GPX collections`. `git log` confirms author and committer are both `Zcxssxx <Zcxssxx@users.noreply.github.com>`. The working tree is clean; `git remote -v` is empty, and no GitHub operation was performed.

## 2026-10-25 inline implementation, Task 8

- Began with failing collection tests for all 14 metadata categories, zero/partial/complete timestamp coverage, distinct file evidence, stable ordering, duplicate source fields, and failed inspections. The existing report was empty for each case; the new aggregation now passes these tests.
- Metadata findings are normalized to `FileInspection.source_path`, validated for positive ordinals and counts (timestamp coverage uses 0/1 and must be within `point_count`), deduplicated by exact path/category/ordinal, and sorted deterministically. Duplicate identities retain the maximum represented occurrence count rather than adding duplicates.
- GPX inspection now emits one timestamp coverage fact per parsed waypoint, route point, and track point: count 1 if a timestamp exists and 0 otherwise. No exact timestamp is retained. This lets the report distinguish no timestamps, partial coverage, and full coverage.
- Invalid metadata facts are omitted with `audit.invalid_metadata_finding`; diagnostics contain no metadata text. Findings from unanalyzed inspections are excluded, while the existing stable parse diagnostics remain.
- Added integration coverage using the same metadata values in two different GPX files and verified that paths remain distinct. A model-level privacy check confirms that creator/name/author/email/link/timestamp/coordinate values do not enter `MetadataFinding`; JSON serialization checks remain in Task 9.
- Native verification: `moon fmt --check` passed; ordinary `moon check` passed with only the two known future redaction record warnings; `moon test audit` passed 17/17; `moon test api` passed 14/14; full `moon test` passed 71/71; native build passed; `moon info --package audit`, `api`, and `model` exited 0.
- `moon test audit --deny-warn` still fails only on unconstructed `RedactionPreview` and `RedactedFile`, reserved for Task 13. No metadata, API, or package warning remains.
- Committed Task 8 locally as `9148c0a feat: report GPX metadata exposure safely`. `git log` confirms author and committer are both `Zcxssxx <Zcxssxx@users.noreply.github.com>`. The working tree is clean; no remote is configured and no GitHub operation was performed.

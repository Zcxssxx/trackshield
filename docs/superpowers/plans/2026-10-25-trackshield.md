# TrackShield Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan inline, task by task. Keep the user’s local-only instruction in force; do not perform GitHub operations. Steps use checkbox syntax for tracking.

**Goal:** Deliver a local-first MoonBit CLI and reusable library that audits GPX collections for repeated endpoints and metadata exposure, then previews or applies redaction only for a user-specified geographic circle.

**Architecture:** Keep the public API and analysis model independent from filesystem access. A GPX adapter owns parsing and serialization, while geometry, collection analysis, redaction planning, and report rendering are deterministic library packages. A native CLI reads one input at a time, aggregates compact inspection results, and writes redacted copies only after an explicit write flag and successful preview.

**Tech Stack:** MoonBit stable toolchain verified immediately before implementation; `2973181701/moongpx` only if its parser/serializer passes the compatibility and adversarial-input gate; `moonbitlang/async` filesystem APIs only at the native CLI boundary if their current docs confirm required directory and safe-write behavior; MoonBit core JSON/argument facilities after API discovery; GitHub Actions configuration based on the current official MoonBit workflow and community templates.

## Global Constraints

- Use MoonBit as the primary implementation language.
- Keep all development local until local implementation and verification are complete; no remote is configured, and no GitHub operation is part of this plan.
- The audit is read-only. Redaction requires an explicitly supplied center and radius, preview is the default, originals are never overwritten, and existing destinations are rejected.
- Do not describe repeated endpoints as a home, workplace, or proof of anonymity.
- Do not print exact coordinates, timestamps, or raw metadata values in default reports.
- Use a default endpoint radius of 500 metres and require at least three distinct source files for a repeated-location finding.
- Support GPX 1.0 and 1.1 only to the degree verified by fixtures; unsupported constructs must produce stable diagnostics rather than be silently claimed as preserved.
- Reject documents containing a DOCTYPE before GPX semantic parsing; verify actual behavior of the exact resolved XML dependency and never resolve external resources.
- Make traversal deterministic and do not follow symbolic links or Windows reparse points by default.
- Keep more than ten useful, reviewable commits as genuine deliverables; never create empty, artificial, backdated, or mechanically split commits.
- Continue the user’s target of at least 3,000 meaningful `.mbt` source lines across production and tests. Reach it only through real functionality and meaningful test coverage; report production and test counts separately.
- Use Git author name `Zcxssxx`; do not substitute another account identity.
- Run `moon fmt --check`, `moon check --deny-warn`, `moon test --deny-warn`, and `moon info` as separate commands; do not pass `--deny-warn` to `moon fmt` or `moon info`.
- Re-check the current official hackathon rules and stable toolchain before fixing CI pins or preparing submission materials. The current official landing page says the October registration and acceptance deadline is 2026-10-31; its displayed page does not expose an update timestamp. The charter and supplemental Feishu pages still need direct confirmation because the current web retrieval did not expose their contents.

---

## Planned File Structure

```text
trackshield/
├── moon.mod
├── moon.pkg
├── trackshield.mbt               # Root-package API facade only where appropriate
├── trackshield_test.mbt
├── trackshield_wbtest.mbt
├── model/                         # Public input, options, diagnostics and report records
├── internal/xmlguard/             # Byte, encoding and DTD preflight checks
├── gpx/                           # GPX dependency adapter and TrackShield-owned mapping
├── geo/                           # Distance, validation and spherical center calculations
├── audit/                         # Endpoint graph and metadata finding aggregation
├── redact/                        # Explicit-zone preview and transformation
├── report/                        # Stable text and JSON rendering
├── api/                           # Reusable public facade
├── cmd/main/                      # Native CLI entry point and filesystem boundary
├── README.md
├── README.mbt.md                  # Executable documentation examples
├── LICENSE
├── THIRD_PARTY_NOTICES.md
├── CHANGELOG.md
├── .gitignore
├── .github/workflows/test.yml
├── testdata/                   # Authored minimal GPX 1.0/1.1 fixtures and README
├── examples/                   # Small redistributable synthetic collections
└── docs/
    ├── privacy-model.md
    ├── formats-and-limits.md
    ├── development.md
    └── superpowers/{specs,plans}/
```

The inspected current scaffold uses the module root for its library package and one subdirectory per package; there is no `src/` source root. It initializes a Git repository, so use the inspected output only as a template and never run `moon new` in this already-initialized repository. On Windows without symlink privilege, create `README.md` as a regular file and update `moon.mod` to point to it. Do not create parallel source roots or hand-edit generated `.mbti` interfaces.

## Public API Contract

The names below are TrackShield-owned and must be implemented in `api` after the module/package syntax is confirmed. If MoonBit syntax or the selected GPX dependency requires a naming adjustment, update this plan and the generated interface together before dependent tasks begin.

```text
pub struct GpxInput { path: String, bytes: Bytes }
pub struct InputLimits { max_file_bytes: Int, max_points_per_file: Int, max_files: Int, max_total_bytes: Int, max_xml_depth: Int, max_xml_elements: Int }
pub struct GeoPoint { latitude: Double, longitude: Double }
pub enum EndpointKind { Start; End }
pub enum Severity { Info; Warning; Error }
pub struct Diagnostic { code: String, severity: Severity, path: String, message: String }
pub enum MetadataCategory { Creator; MetadataName; MetadataDescription; AuthorName; AuthorEmail; Link; TrackName; TrackDescription; RouteName; RouteDescription; WaypointName; WaypointDescription; PointTimestamp; Extensions }
pub struct EndpointObservation { source_path: String, track_ordinal: Int, kind: EndpointKind, observation_index: Int, point: GeoPoint }
pub struct MetadataFinding { source_path: String, category: MetadataCategory, item_ordinal: Int, occurrence_count: Int } // PointTimestamp uses 0/1 presence per point; other categories require a positive occurrence count.
pub struct FileInspection { source_path: String, endpoints: Array[EndpointObservation], metadata_findings: Array[MetadataFinding], diagnostics: Array[Diagnostic], track_count: Int, point_count: Int, analyzed: Bool }
pub struct AuditOptions { radius_m: Double, min_distinct_files: Int, include_coordinates: Bool }
pub struct EndpointEvidence { source_path: String, track_ordinal: Int, kind: EndpointKind, observation_index: Int }
pub struct RepeatedLocation { id: String, distinct_file_count: Int, distinct_track_count: Int, evidence: Array[EndpointEvidence], center: GeoPoint?, max_distance_from_center_m: Double?, wide_component: Bool }
pub struct AuditReport { options: AuditOptions, repeated_locations: Array[RepeatedLocation], metadata_findings: Array[MetadataFinding], diagnostics: Array[Diagnostic] }
pub struct RedactionOptions { center: GeoPoint, radius_m: Double, remove_metadata: Array[MetadataCategory] }
pub struct RedactionPreview { source_path: String, points_removed: Int, segments_created: Int, routes_removed: Int, waypoints_removed: Int, metadata_fields_removed: Int, output_would_be_empty: Bool, diagnostics: Array[Diagnostic] }
pub struct RedactedFile { bytes: Bytes, preview: RedactionPreview }

pub fn inspect_gpx(input: GpxInput, limits: InputLimits) -> FileInspection
pub fn audit_collection(inspections: Array[FileInspection], options: AuditOptions) -> AuditReport
pub fn preview_redaction(input: GpxInput, options: RedactionOptions, limits: InputLimits) -> RedactionPreview
pub fn redact_gpx(input: GpxInput, options: RedactionOptions, limits: InputLimits) -> Result[RedactedFile, Diagnostic]
pub fn make_geo_point(latitude: Double, longitude: Double) -> Result[GeoPoint, Diagnostic]
pub fn make_input_limits(max_file_bytes: Int, max_points_per_file: Int, max_files: Int, max_total_bytes: Int, max_xml_depth: Int, max_xml_elements: Int) -> Result[InputLimits, Diagnostic]
pub fn make_audit_options(radius_m: Double, min_distinct_files: Int, include_coordinates: Bool) -> Result[AuditOptions, Diagnostic]
pub fn make_redaction_options(center: GeoPoint, radius_m: Double, remove_metadata: Array[MetadataCategory]) -> Result[RedactionOptions, Diagnostic]
pub fn render_text(report: AuditReport) -> String
pub fn render_json(report: AuditReport) -> String
pub fn default_input_limits() -> InputLimits
pub fn default_audit_options() -> AuditOptions
```

`GpxInput.bytes` and `EndpointObservation.point` contain sensitive source data. The default report model must not copy endpoint coordinates into `EndpointEvidence`; the optional center is present only when `include_coordinates` is true. Diagnostic text must identify a failure without embedding raw metadata, coordinates, timestamps, XML snippets, or secret file contents. Stable diagnostic codes are lowercase dot-separated strings such as `input.file_too_large`, `xml.doctype_forbidden`, and `gpx.unsupported_namespace`.

## Implementation Tasks

### Task 1: Refresh official competition and toolchain facts; scaffold the module

**Files:** `findings.md`, `progress.md`, `moon.mod`, root and package `moon.pkg` files generated from the current template, `.gitignore`, initial package source directories.

**Interfaces:** Establish module namespace `Zcxssxx/trackshield` and confirm the exact package import paths and current generated module format before adding public types.

- [x] Re-open the official October landing page, formal charter, and supplemental page. Record displayed update dates, application fields and documents, project acceptance dates, rolling-review and revision policy, public-repository and source-control rules, licensing, Mooncakes, CI, and stable-toolchain requirements. Mark inaccessible or absent data as `待确认` and retain the original URLs.
- [x] Run `moon version --all`; compare the result with latest stable release information available from an official MoonBit source. The local output was collected; an authoritative version string was not exposed by the online official sources examined, so the latest-stable comparison is still pending.
- [x] From an empty temporary directory, run `moon new <temp-path> --user Zcxssxx --name trackshield`; inspect the generated manifest, package layout, and CLI template. Do not repeat the unsupported `--dry-run` probe.
- [x] Create the actual module metadata and package skeleton by adapting the inspected template without invoking `moon new` in this already initialized repository and without replacing `.git`, `docs/`, `findings.md`, `progress.md`, or `task_plan.md`.
- [x] Run `moon check --deny-warn` on the generated skeleton. Expected: successful check and only intentional generated files. Result: exit 0, “Finished. moon: ran 6 tasks, now up to date”.
- [x] Run `moon fmt --check`. The first check found noncanonical manifest formatting; `moon fmt` normalized it, and the fresh check returned exit 0.
- [x] Run `moon run cmd/main` to verify the scaffold entry point executes. Result: exit 0 and output `TrackShield`.
- [x] Commit the module skeleton only after the source tree and manifests are self-consistent: `feat: scaffold TrackShield MoonBit module` (`c07d23e`).

**Acceptance:** refreshed rules and unknowns are recorded; the local toolchain version is recorded and its latest-stable status is verified or explicitly left pending with evidence; the root remains a local Git repository with no remote; the empty-template probe was inspected and safely removed before adapting the module files.

### Task 2: Probe GPX/XML dependencies and freeze the adapter boundary

**Files:** `moon.mod`, `gpx/moon.pkg`, `gpx/dependency_probe_test.mbt`, `findings.md`.

**Interfaces:** The probe exercises the selected dependency only. The TrackShield adapter boundary remains `inspect_gpx(GpxInput, InputLimits) -> FileInspection` and `redact_gpx(GpxInput, RedactionOptions, InputLimits) -> Result[RedactedFile, Diagnostic]`.

- [x] Inspect exact Mooncakes release metadata and licenses for `2973181701/moongpx` and the resolved XML dependency; record the transitive `moonbitlang/x` version. No filesystem package is needed for this pure parser gate.
- [x] Attempt `moon ide doc` after dependency resolution. The installed tool reports that no core metadata is available for any backend; inspect the exact pinned sources and confirm their APIs with compiled probe tests instead. Record this limitation and the actual function names in `findings.md`.
- [x] Add authored inline fixtures for GPX 1.0, GPX 1.1 with a default namespace and extension payload, a prefixed root, and malformed XML. No upstream fixtures or implementation were copied. DOCTYPE/entity and byte/encoding cases are moved to the TrackShield-owned preflight tests in Task 4.
- [x] Write probe tests for GPX 1.0/1.1 parsing, default-namespace semantic round trip including extension data, prefixed-name rejection, and malformed XML rejection.
- [ ] Add bounded adversarial-input tests for oversized bytes, a deep element tree, huge text, DOCTYPE/internal/external-entity syntax, malformed encodings, and a temporary sentinel. These belong at the TrackShield preflight boundary in Task 4 so unsafe bytes never reach the dependency parser.
- [ ] If the dependency cannot meet the spec, document the observed gap and test an alternative adapter or implement a narrow TrackShield-owned XML boundary; do not silently weaken the safety or preservation claims.
- [ ] Lock the dependency decision and TrackShield-owned adapter mapping in `findings.md` and this plan. `moon test gpx` currently passes 4/4, but emits `unused_package` because the package dependency is consumed only in test files; rerun `moon test gpx --deny-warn` and `moon check --deny-warn` once the production adapter in Task 5 consumes it.
- [ ] Commit the compatibility findings and authored probes: `test: establish GPX parser compatibility gate`.

**Acceptance:** the exact dependency and supported namespace/version/extension behavior are recorded and backed by passing authored tests. Task 4 must establish the input-safety boundary before Task 5 calls the parser. Compiler warning-denial is verified after the production adapter consumes the pinned dependency.

### Task 3: Define public domain models, diagnostics, and validated options

**Files:** `model/moon.pkg`, `model/diagnostic.mbt`, `model/input.mbt`, `model/audit.mbt`, `model/redaction.mbt`, `model/model_test.mbt`, `api/moon.pkg`, `api/api.mbt`.

**Interfaces:** Implement the Public API Contract above. `inspect_gpx` and `audit_collection` must return structured diagnostics for invalid user data instead of panicking. Constructors/default functions validate finite geographic values, positive radii, valid latitude/longitude, positive resource limits, and support thresholds. XML depth and element limits have hard ceilings of 256 and 2,000,000; defaults are 128 and 500,000.

- [x] Write tests for invalid geographic coordinates including NaN/infinity, zero/negative/out-of-range radii, zero support, resource limits and caps, defensive copying of redaction category input, and defaults.
- [x] Define stable diagnostic codes and test that rendering omits a sensitive source path while preserving the stable code and safe message.
- [x] Implement validated `make_geo_point`, `make_input_limits`, `make_audit_options`, and `make_redaction_options`; add default settings and a `GpxInput` constructor. Readonly MoonBit `pub struct` types prevent construction or mutation from outside their defining package; the redaction constructor snapshots the caller's category array.
- [x] Re-export model types and validated constructors from `api`; `moon info --package api` and `moon info --package model` generated the intended interfaces. No fake operational API stubs are added; parsing, auditing, and redaction entry points will be introduced with real implementations in later tasks.
- [x] `moon test model` (10/10) and `moon test api` (1/1) pass. `moon check --deny-warn` still reports `struct_never_constructed` for result records that later parser/audit/redaction tasks will produce. Re-run warning-denial after those implementations construct the types; do not suppress the diagnostics or add dummy constructors solely to silence them.
- [x] Commit: `feat: define TrackShield API and diagnostic model` (`37bef2f`).

**Acceptance:** generated `.mbti` exposes the intended readonly model and validated constructors; invalid options produce stable structured errors; package tests pass. Full warning-denial is confirmed after the planned producers for each result type are implemented.

### Task 4: Implement bounded input and XML preflight

**Files:** `internal/xmlguard/moon.pkg`, `internal/xmlguard/limits.mbt`, `internal/xmlguard/xml_lex.mbt`, `internal/xmlguard/xmlguard_test.mbt`, `api/api.mbt`.

**Interfaces:** Internal `validate_input(path: String, bytes: Bytes, limits: InputLimits) -> Array[Diagnostic]`; internal `preflight_xml(bytes: Bytes, max_depth: Int, max_elements: Int) -> Result[Unit, Diagnostic]`. The preflight rejects DOCTYPE, malformed markup, nesting beyond the documented hard cap, and excessive element counts before any GPX model is allocated. Wire the checks into inspection, preview, and redaction before invoking the GPX parser.

- [x] Test byte limits at `max_file_bytes - 1`, exactly the limit, and one byte over. Public parser-call short-circuit coverage is deferred to Task 5, when `inspect_gpx` exists.
- [x] Test lexical handling of actual `<!DOCTYPE ...>` declarations, comments containing the same text, CDATA containing the text, quoted attribute content, UTF-8 BOM, malformed UTF-8, processing instructions, and prefixed GPX element rejection.
- [x] Implement the bounded XML tokenizer and input validator. The functions are in `internal/xmlguard`; Task 5 must invoke them before calling the dependency parser.
- [ ] `moon test internal/xmlguard --deny-warn` and `moon check --deny-warn` are currently blocked by eight planned-but-not-yet-constructed public result records; full warning-denial remains scheduled after parser/audit/redaction producers exist. Ordinary package tests pass (13/13), with no XML guard warnings.
- [ ] Commit: `feat: reject unsafe and oversized GPX input`.

**Acceptance:** preflight helpers are deterministic, bounded, reject unsafe input, perform no external I/O, and omit document content from diagnostics. Task 5 owns the public-call-path proof that the helpers run before model parsing.

### Task 5: Build the GPX adapter and track/metadata extraction

**Files:** `gpx/adapter.mbt`, `gpx/extract_tracks.mbt`, `gpx/extract_metadata.mbt`, `gpx/dependency_probe_test.mbt`, `internal/xmlguard/`, `model/audit.mbt`, `model/diagnostic.mbt`, `api/api.mbt`, `api/api_test.mbt`, and the generated package interfaces.

**Interfaces:** `inspect_gpx(input, limits) -> FileInspection`; internal adapter functions map the dependency model to TrackShield records. The endpoint rule is first point in the first non-empty track segment and last point in the last non-empty track segment. Each file contributes one source identity.

- [x] Test GPX 1.0 and 1.1, multiple tracks and segments, leading/trailing empty segments, a wholly empty track, route/waypoint-only data, mixed namespace rejection, and malformed XML. Every parse enters through `internal/xmlguard.validate_input`; API tests verify DTD/size rejection and safe malformed-input diagnostics. A malformed file beside a valid file belongs to the collection-level Task 7.
- [x] Test creator, metadata name/description, author name/email, links, track/route/waypoint names and descriptions, point timestamp presence, and extension presence. Findings retain only category, ordinal and count, never source field values.
- [x] Test the exact point-count boundary and one point above it. XML preflight counts GPX point elements and rejects over-limit input before semantic model allocation; adapter counting remains as a defensive consistency check.
- [x] Implement the adapter over the confirmed dependency types. Unsupported namespaces receive stable diagnostics; parser failures map to a safe static diagnostic, and failed/partial input never returns `analyzed = true`.
- [x] Ensure routes do not produce endpoint observations; a multi-track input keeps one source path while assigning stable 1-based track ordinals and file-local observation indices.
- [ ] `moon test gpx --deny-warn` and `moon check --deny-warn` currently fail only on five planned audit/redaction result records not yet constructed; no unused GPX dependency warning remains. Ordinary tests pass: xmlguard 14/14, gpx 5/5, model 10/10, and api 10/10. The dependency compatibility tests still round-trip GPX 1.1 including extension payloads and parse GPX 1.0.
- [x] Commit: `feat: inspect GPX tracks and metadata` (`8aefcb6`).

**Acceptance:** file inspection obeys endpoint and metadata rules, supports the verified GPX versions, rejects byte/XML/point limits before semantic parsing, and never echoes metadata values.

### Task 6: Implement geodesic distance and spherical center calculations

**Files:** `geo/moon.pkg`, `geo/distance.mbt`, `geo/center.mbt`, `geo/geo_test.mbt`, `model/diagnostic.mbt`, `api/moon.pkg`, `api/api.mbt`, and generated interfaces.

**Interfaces:** `distance_m(a: GeoPoint, b: GeoPoint) -> Double`; `spherical_mean(points: Array[GeoPoint]) -> Result[GeoPoint, Diagnostic]`; `max_distance_from_center(points: Array[GeoPoint], center: GeoPoint) -> Double`.

- [x] Add fixed expected-distance tests for identical coordinates, a known short equatorial displacement, antimeridian crossing, high latitudes, poles, and radius-boundary cases with a 1 cm absolute tolerance.
- [x] Add center tests for identical points, a cluster crossing the antimeridian, a high-latitude cluster, and antipodal/near-zero resultant vectors.
- [x] Implement haversine distance with normalized longitude delta and spherical-mean center. Return `geo.undefined_center` when the resultant is unstable rather than selecting an arbitrary point.
- [x] Verify symmetry, non-negative output, identity distance, and inclusive threshold comparisons at `r - 1 cm`, `r`, and `r + 1 cm`.
- [x] `moon test geo --deny-warn` remains blocked only by two later redaction result records (`RedactionPreview`, `RedactedFile`) that remain intentionally unconstructed until the redaction task. Ordinary geometry tests pass 11/11; no geometry warning is present.
- [x] Commit: `feat: add robust geographic calculations` (`cd9e4ef`).

**Acceptance:** numerical tests pass on the native target; distances use metres and the mean Earth radius, while runtime radius comparisons are inclusive and exact (`distance_m <= radius_m`). The 1 cm tolerance is only for numerical reference assertions.

### Task 7: Aggregate repeated endpoints across distinct files

**Files:** `audit/moon.pkg`, `audit/endpoints.mbt`, `audit/audit_test.mbt`, `api/api.mbt`.

**Interfaces:** `audit_collection(inspections: Array[FileInspection], options: AuditOptions) -> AuditReport`; each connected component is qualified by distinct file count, while distinct track count is reported separately.

- [x] Add tests where three separate files qualify, two separate files do not qualify, many tracks in one file count as one source, duplicate endpoints from one track count as observations but not tracks, repeated normalized paths count as one source, and input reordering preserves every finding field and diagnostic. The CLI canonicalizes file paths before inspection; direct library calls use the exact normalized `FileInspection.source_path` string as the source identity.
- [x] Add tests for a pairwise-near transitive chain whose component radius is wider than the configured radius; set `wide_component = true`, retain all evidence, and add a stable `audit.wide_endpoint_component` warning.
- [x] Add tests for identical endpoints, no endpoints, failed coordinate-input diagnostics on an unanalyzed inspection, duplicate paths, an antipodal component with no stable center, and a component exactly at the configured distance. `GeoPoint`'s validated constructor prevents invalid coordinates from entering a valid inspection.
- [x] Implement a deterministic 3D spatial proximity graph using the geo package. Sort observations by stable source path, track ordinal, kind, observation index, and coordinates before assigning stable finding IDs.
- [x] Omit the center unless `include_coordinates`; always report distinct files, distinct tracks, evidence references, and max center distance when a stable center exists. The optional max-distance field is absent if the spherical center is undefined; that component is not marked wide without a computable radius and carries `geo.undefined_center`.
- [x] Run `moon test audit --deny-warn` and `moon test --deny-warn`; both currently fail only because `RedactionPreview` and `RedactedFile` are intentionally not yet constructed before the redaction task. Ordinary full tests pass 62/62.
- [x] Commit: `feat: find repeated endpoints across GPX collections` (`e8c486f`).

**Acceptance:** repeated-location findings are reproducible under input reordering, respect distinct-file thresholds, and never label a location or person.

### Task 8: Add safe metadata audit aggregation

**Files:** `audit/metadata.mbt`, `audit/metadata_test.mbt`, `gpx/extract_metadata.mbt`, `api/api.mbt`, `api/api_test.mbt`.

**Interfaces:** Metadata findings are aggregated by stable path/category/item ordinal; values remain absent from the public metadata report.

- [x] Add tests for every category in `MetadataCategory`, including per-point timestamp coverage with zero, partial, and complete timestamp presence.
- [x] Test that identical field values in different files yield separate path evidence; verify the audit model exposes only path/category/ordinal/count. Serialized text/JSON privacy assertions are in Task 9, where a serializer exists.
- [x] Test that duplicate entries in category aggregation do not double-count one source field. Duplicate `remove_metadata` selection is checked with the redaction option tests in Task 13.
- [x] Implement deterministic path/category/ordinal aggregation, per-point timestamp coverage facts, and stable diagnostic merge. Do not include values even when a parse error occurs.
- [x] Run `moon test audit --deny-warn`; it remains blocked only by the two unconstructed redaction result records until Task 13.
- [x] Commit: `feat: report GPX metadata exposure safely` (`9148c0a`).

**Acceptance:** all spec categories are represented, counts are explicit, order is stable, and sensitive values are not retained in report records.

### Task 9: Render stable text and JSON reports

**Files:** `report/moon.pkg`, `report/text.mbt`, `report/json.mbt`, `report/report_test.mbt`, `api/api.mbt`.

**Interfaces:** `render_text(AuditReport) -> String`; `render_json(AuditReport) -> String`. Both render deterministic ordering and omit coordinates unless the report explicitly includes a center.

- [x] Add golden tests for an empty collection, one cluster with metadata findings, one wide chained component, partial parse diagnostics, and coordinate opt-in.
- [x] Add JSON escaping tests for quotes, backslashes, newlines, control characters, non-ASCII text, and paths. Parse the resulting JSON using MoonBit core JSON in the test to prove syntactic validity.
- [x] Add privacy regression tests against serialized reports and the public API: default output and audit results omit centers and raw metadata/timestamps; coordinate opt-in exposes the stable cluster center only.
- [x] Implement explicit field order and stable arrays. JSON uses core JSON string escaping and valid numeric formatting; text includes the privacy limitation statement. Re-export both renderers from the public `api` package.
- [x] Run `moon test report --deny-warn`; it exits 1 only on the two known, unconstructed redaction result records (`RedactionPreview`, `RedactedFile`), which are produced by Task 13. `moon test report` passes 8/8; the complete suite passes 80/80.
- [x] Commit `6290061`: `feat: render deterministic privacy-safe reports`.

**Acceptance:** golden outputs are deterministic, syntactically valid JSON, and default reports do not reveal raw values or exact coordinates.

### Task 10: Implement deterministic audit CLI and file traversal

**Files:** `cmd/main/moon.pkg`, `cmd/main/main.mbt`, `cmd/main/args.mbt`, `cmd/main/input_files.mbt`, `cmd/main/audit_command.mbt`, `cmd/main/cli_wbtest.mbt`, `README.md`, `examples/repeated-endpoints/*.gpx`.

**Interfaces:** Native executable command `trackshield audit <path>... [--radius-m <number>] [--min-files <positive-int>] [--format text|json] [--show-coordinates] [--max-file-bytes <positive-int>] [--max-points <positive-int>] [--max-files <positive-int>] [--max-total-bytes <positive-int>]`; filesystem adapter loads and inspects one file at a time and passes `Array[FileInspection]` to the library.

- [x] Record argument and filesystem signatures. `moon ide doc` cannot load core metadata on this installation, so signatures were verified against the installed core source and pinned async 0.22.5 generated interface/source. `@env.args()` includes the executable prefix; the CLI adapter strips it before passing tokens to `Command.parse(argv=...)`. `@fs.kind(..., follow_symlink=false)` classifies static symlinks/reparse points as `SymLink`; an authored Windows junction test confirms traversal skips it.
- [x] Add CLI tests for help, missing paths, invalid option values, invalid paths, unsupported extensions, empty directories, deterministic nested directory order, symlink/reparse exclusion (including a file beneath a junction), canonical path alias deduplication, and partial-success exit behavior. A missing input exercises `input.path_unreadable`; ACL-denied regular-file behavior is not directly tested on this Windows host.
- [x] Test collection boundaries at `max_files` and `max_total_bytes`, then one file and one byte over; excess inputs receive stable diagnostics and are not parsed. `max_file_bytes` exact/+1 boundaries are also covered.
- [x] Test defaults, overrides, malformed values, zero, and negative values for resource limits; tests verify configured limits reach the loader.
- [x] Implement CLI status policy: 0 for an analyzed collection (warnings allowed), 1 for one or more errors with a report, and 2 for command-line errors before a report. The built native executable directly returned 2 for an invalid command and 1 for a mixed valid/missing collection.
- [x] Test reports on stdout, diagnostic summaries on stderr, and no raw fixture text in diagnostics. A direct executable run captured/parsed JSON stdout separately from stderr and reported exit 1 for a mixed collection.
- [x] Add runnable text, JSON, and override audit invocations to README and execute all three successfully against the synthetic example collection.
- [x] Run help, targeted CLI tests, full tests, native build, `moon info --package cmd/main`, and `moon fmt --check`. `moon test cmd/main --deny-warn` and `moon build --target native --deny-warn` were also run; both remain nonzero only because `RedactionPreview` and `RedactedFile` are intentionally unconstructed until Task 13. The Windows native build also prints an upstream async C `EINVAL` macro-redefinition warning. Ordinary `moon check` and native build succeed.
- [x] Committed as `407f834 feat: add deterministic audit CLI`; the commit author and committer are both `Zcxssxx <Zcxssxx@users.noreply.github.com>`.

**Acceptance:** CLI works against files and directories on the current Windows native host, its junction tests prove links are not traversed even through an intermediate component, aliases are deduplicated, and direct-executable exit statuses match the specified policy. Permission-denied ACL behavior and hosted CI remain unverified.

### Task 11: Plan redaction for explicit user-supplied circles

**Files:** `redact/moon.pkg`, `redact/preview.mbt`, `redact/options.mbt`, `redact/redaction_test.mbt`, `api/api.mbt`, `docs/privacy-model.md`.

**Interfaces:** `preview_redaction(input: GpxInput, options: RedactionOptions, limits: InputLimits) -> RedactionPreview`; the supplied circle is independent of audit findings. Preview computes exact change counts but writes nothing.

- [x] Test valid/invalid centers and radii, inclusive radius boundary, dateline and polar inclusion, duplicate metadata-category selections, deterministic no-op zones, track splitting/removal patterns, multiple original segments, route/waypoint removal, selected metadata across all categories, and empty output.
- [x] Verify exact preview counts for removed track/route/waypoint points, additional retained segment runs, empty routes, and selected metadata. `docs/privacy-model.md` defines non-overlapping count semantics and behavior for invalid/unsupported input.
- [x] Implement preview from explicit options only. No audit or cluster data is accepted or used to infer a zone.
- [x] Add a real API integration test that observes a directory and source path before/after preview; no path is created, and `api` has no filesystem dependency.
- [x] Run `moon test redact --deny-warn`. It exits 1 only for `model.RedactedFile` (`struct_never_constructed`), whose producer is Task 12; ordinary `moon test redact` passes 13/13, and the separate purity integration test passes 1/1. No placeholder constructor or warning suppression was added.
- [x] Commit: `2da0689 feat: preview explicit-zone GPX redaction`; task review approved with no Critical/Important findings. The reviewer recorded the pending warning as Minor until Task 12 constructs `RedactedFile`.

**Acceptance:** preview is pure, deterministic, and reports all affected object counts without writing or inferring a zone. The task-specific warning-strict command was run but remains nonzero solely on the result type scheduled for Task 12; final warning-strict verification is pending that producer.

### Task 12: Transform track, route, waypoint, and selected metadata safely

**Files:** `redact/transform.mbt`, `redact/metadata.mbt`, `redact/transform_test.mbt`, `gpx/adapter.mbt`.

**Interfaces:** `redact_gpx(GpxInput, RedactionOptions, InputLimits) -> Result[RedactedFile, Diagnostic]`; implementation removes points inside the explicit circle, splits each retained run into distinct segments, filters routes/waypoints, and removes only selected metadata categories.

- [x] Write failing tests for leading/middle/trailing/consecutive/all-point runs, boundary points, multiple segments, route/waypoint removal, and empty output. Add tests for every selected metadata category, preserved unselected fields/extensions/unknown fields, GPX 1.0, inherited namespace bindings, BOM/CRLF/supplementary-plane spans, and stable refusal when opaque metadata cannot be assigned safely.
- [x] Use UTF-16 source offsets from the exact pinned XML dependency to splice only selected/deleted source ranges. Preserve untouched source. The semantic GPX serializer was rejected after source inspection showed that it drops unknown optional fields and inherited namespaces and upgrades GPX 1.0 to 1.1.
- [x] Split retained track-point runs into separate segments; remove route/waypoint points inside the inclusive circle; omit empty tracks/routes and refuse an empty result. Reparse every successful candidate through the shared hardened adapter and validate point, segment, route, waypoint, circle, version, and metadata invariants.
- [x] Add source-span regressions for direct text/CDATA/comments/PIs. Initial review found that direct opaque content on empty/split segments could be lost; the fix tracks it as segment-owned content, preserves it when unambiguous, and refuses ambiguous splits with `gpx.lossless_redaction_unsupported`. Ordinary formatting whitespace remains non-semantic.
- [x] Align public preview and transformed-result metadata counts for retained originally empty segments. Tests verify exact counts for unselected custom children/attributes, direct CDATA/text, duplicate category choices, and omitted-parent/track controls.
- [x] Run `moon test redact --deny-warn` (32/32), the preview purity integration tests with warning denial (2/2), and the full `moon test --deny-warn` suite (122/122). `moon check --deny-warn`, `moon fmt --check`, native build, interface generation, and `git diff --check` also pass. The first clean native C build emitted an upstream Windows SDK `EINVAL` macro-redefinition warning; the incremental build after fixes emitted none.
- [x] Commit feature as `5bcb0c7 feat: redact GPX data without bridging removed areas`; fix review findings in `18f2199 fix: preserve opaque segment content and exact redaction counts`. Combined Task 12 review approved with no Critical/Important findings; the upstream C warning remains Minor.

**Acceptance:** originals are untouched, every returned candidate reparses, and all unselected supported fields/extensions remain unchanged or the operation fails closed with a stable diagnostic. This is an in-memory transformation; filesystem publication is Task 13.

### Task 13: Add safe filesystem writes and redaction CLI

**Files:** `cmd/main/redact_command.mbt`, `cmd/main/safe_output.mbt`, `cmd/main/redact_cli_wbtest.mbt`, `README.md`, `docs/formats-and-limits.md`.

**Interfaces:** `trackshield redact <path>... --center LAT,LON --radius-m N [--remove-metadata CATEGORY,...] [--write --output-dir DIR]`. Without `--write`, the command previews only. With `--write`, every destination path is new and is re-parsed before final publication.

- [x] Test preview mode creates no directory or file; `--write` without `--output-dir`, with existing output dir, with output equal to an input directory, and with output nested under input directory all fail before writing. Test duplicate basenames from separate input directories; reject colliding derived destinations before writing. Focused CLI suite: 18/18, including staging ownership and Unicode diagnostic line-separator regressions.
- [x] Test a destination with one valid and one invalid input: failed files are not published as successful outputs and the summary names each diagnostic without leaking source values.
- [x] Implement path canonicalization and containment checks using confirmed filesystem APIs. Reject static symlink/reparse traversal and any destination overlap with inputs. Concurrent hostile parent replacement remains unsupported because path APIs do not provide a handle-relative no-follow boundary; the trusted-tree limit is documented.
- [x] Write to a newly created staging sibling directory, sync and close all files, re-open and re-parse each staged GPX, then publish by per-file exclusive creation. The Windows rename API has a copy fallback and does not guarantee same-volume atomic publication on all supported systems, so partial publication recovery is documented; existing paths are never overwritten.
- [x] Print exact counts and output paths, with a reminder that cleaned files and reports remain sensitive. Exit 0 for successful preview/write and 2 for usage, path, destination, or I/O errors.
- [x] Run preview and write examples in temporary directories and compare original file bytes before and after; expected: originals byte-identical. Native smoke assertions passed for preview, three outputs, independent reparse/audit, repeat-destination rejection, cleanup, and unchanged source bytes.
- [x] Commit: `feat: add preview-first redaction CLI` (`d026f48`). Independent review found no Critical/Important issue; a Minor Unicode line-separator diagnostic issue was reproduced RED/GREEN and re-reviewed as resolved.

**Acceptance:** preview has no side effects, write requires explicit confirmation, collisions and input/output overlap are rejected, and generated files are validated before publication.

### Task 14: Complete adversarial, compatibility, and regression tests

**Files:** `testdata/README.md`, `*/*_test.mbt`, `cmd/main/*_test.mbt`, `docs/formats-and-limits.md`.

**Interfaces:** Tests exercise only the public API or one package boundary at a time; expected error cases compare stable diagnostic codes rather than parser-specific prose.

- [x] Create a synthetic three-file collection whose starts form exactly one qualifying cluster and a separate below-threshold two-file collection. `testdata/README.md` records that all fixture GPX files are original, deterministic synthetic data with no recorded activities or personal data.
- [x] Complete cases from the spec: dateline, high latitude, identical points, exact radius, empty tracks, multi-segment tracks, GPX 1.0/1.1, transitive wide clusters, duplicate file support, sensitive default output, opt-in center, preview no-write, destination collision, segment splits, selected metadata removal, preserved unselected extensions, malformed XML, namespaces, DOCTYPE, external entity, oversized file, and unreadable path. Existing focused tests cover these requirements; the new CLI fixtures also exercise default support thresholds end to end.
- [x] Add property-style deterministic tests: permuting source file order preserves full JSON bytes; repeating a CLI audit gives identical report bytes; generated redaction cases check coordinate ranges and ensure retained waypoints, route points, and track points all remain outside the explicit zone. The GPX parser's longitude interval is `[-180, 180)`, as confirmed in the pinned dependency source/tests; `+180` is invalid GPX input even though the standalone model constructor accepts it.
- [x] Add regression tests for each previously observed failure and keep the fixture minimal for the behavior under test. The new coordinate property asserts expected retained point/segment counts to avoid vacuous route/waypoint checks.
- [x] Run targeted CLI/redaction tests and `moon test --deny-warn` for the whole module (142/142). `moon fmt --check`, `moon check --deny-warn`, native build, `moon info`, and `git diff --check` pass. Clean native C compilation retains the previously recorded upstream `moonbitlang/async` C4005 warning on `EINVAL`.
- [x] Commit: `test: cover GPX privacy and redaction edge cases` (Task 14 commit recorded in the progress ledger).

**Task 14 review:** Independent review confirmed the fixtures yield exactly one three-file cluster versus no below-threshold cluster and that output-order assertions compare full JSON. It requested non-vacuous point counts and CLI status/stderr assertions; these were added and the reviewer approved the follow-up. The suggestion to include `+180` was not applied because the pinned GPX parser rejects it under its documented half-open longitude range; this format constraint is asserted in the test and is distinct from the broader standalone `GeoPoint` constructor range.

**Acceptance:** every acceptance item in the design specification maps to a named passing test or a documented platform limitation.

### Task 15: Write usable documentation, example collection, and provenance

**Files:** `README.md`, `examples/README.md`, `examples/repeated-endpoints/`, `docs/privacy-model.md`, `docs/formats-and-limits.md`, `docs/development.md`, `THIRD_PARTY_NOTICES.md`, `CHANGELOG.md`.

**Interfaces:** Documentation commands must match the actual executable help, option names, exit codes, and supported target matrix.

- [x] Add a self-contained synthetic collection of three GPX files with endpoints that make one documented cluster; include no real routes or coordinates.
- [x] Document install/build/run/test commands, audit examples in text and JSON, redaction preview, explicit write flow, metadata category names, limits, unsupported namespace/extension behavior, and the distinction between clues and privacy guarantees.
- [x] Document that reports, paths, and cleaned GPX exports may still contain sensitive information and should be handled accordingly.
- [x] Record each direct and transitive dependency name, exact version, upstream URL, license, bundled/copy status, and attribution obligations. Record test fixture origin and license; state clearly that authored fixtures are synthetic and original.
- [x] Add an OSI-approved root license after verifying the selected SPDX identifier and include any required dependency notices without implying dependency ownership.
- [x] Execute every README shell command on the actual project and fix any mismatch before commit.
- [ ] Commit meaningful documentation/provenance changes: `docs: document TrackShield workflows and provenance`.

**Acceptance:** a reviewer can build and run every documented example locally, understand limitations, and trace every non-original dependency and fixture.

### Task 16: Configure CI from current MoonBit workflow guidance

**Files:** `.github/workflows/test.yml`, `.gitignore`, `docs/development.md`.

**Interfaces:** CI checks the exact stable MoonBit toolchain required by the refreshed current rules and the local project; no CI claim is made until a remote CI run exists.

- [ ] Use current official MoonBit CI/setup documentation and locally verified command help to add a workflow that checks out source, installs the selected stable toolchain, resolves locked Mooncakes dependencies, runs `moon fmt --check`, `moon check --deny-warn`, `moon test --deny-warn`, and builds/tests each actually supported target separately. Do not access the user-linked GitHub reference repositories during this local-only phase.
- [ ] Include `moon info` without `--deny-warn`, then assert no unintended generated `pkg.generated.mbti` diff remains.
- [ ] Execute the same workflow commands locally on native. Execute wasm-gc or other targets only where project dependencies and CLI boundaries support them; document skipped/unsupported targets rather than claiming coverage.
- [ ] Validate YAML syntax locally with an available parser; do not push to run hosted CI during this local-only phase. After the user allows GitHub activity and the active identity is confirmed as `Zcxssxx`, compare the workflow with the user-linked [existing CI example](https://github.com/PaiGack/moonbitlang-OSC2026/blob/main/.github/workflows/test.yml) and [MoonBit community workflow templates](https://github.com/moonbit-community/.github/tree/main/workflow-templates); record any appropriate changes for review before remote work.
- [ ] Commit: `ci: add MoonBit quality checks`.

**Acceptance:** workflow is syntactically valid, pins match refreshed rules and current stable, commands match real local help, and local results are recorded. Hosted CI remains unverified until GitHub work is later allowed.

### Task 17: Final local verification and submission-readiness review

**Files:** `task_plan.md`, `findings.md`, `progress.md`, `docs/development.md`, any intentional API snapshots.

**Interfaces:** No functional API changes unless verification uncovers a concrete defect; any correction returns through its package test and verification cycle.

- [ ] Run and record `moon version --all` and compare with the exact CI installation. Confirm both match the current stable version selected from an official source and the current competition rule, or explain the discrepancy.
- [ ] Run separately and record full exit status/output summaries for `moon fmt --check`, `moon check --deny-warn`, `moon test --deny-warn`, `moon build --target native --deny-warn`, supported non-native build/test targets, `moon run cmd/main -- --help`, and every documented example.
- [ ] Run `moon info` with no warning-denial argument; inspect all `pkg.generated.mbti` changes and retain only intentional public API snapshots.
- [ ] Count `.mbt` lines by production and tests using a reproducible PowerShell command that includes tracked `.mbt` files and excludes generated build directories. Report the exact counts and do not add nonfunctional code to hit the target.
- [ ] Use this count command after all source changes are committed; it separates implementation from test files and excludes generated build directories:

```powershell
$mbtFiles = @(git ls-files -- '*.mbt' | Where-Object { $_ -notmatch '(^|/)(_build|target)/' })
$lineRows = foreach ($file in $mbtFiles) {
  $kind = if ($file -match '(_test|_wbtest)\.mbt$') { 'tests' } else { 'production' }
  [pscustomobject]@{ Kind = $kind; Lines = (Get-Content -LiteralPath $file).Count }
}
$lineRows | Group-Object Kind | ForEach-Object {
  [pscustomobject]@{ Kind = $_.Name; Files = $_.Count; Lines = ($_.Group | Measure-Object -Property Lines -Sum).Sum }
} | Format-Table -AutoSize
```

If the total is below 3,000, add only missing meaningful, in-scope behavior or tests that improve user value and confidence; do not report the target as met until the total reaches 3,000.
- [ ] Inspect `git status --short`, `git diff --check`, `git log --oneline --decorate`, `git shortlog -sne`, `git remote -v`, `git branch --show-current`, all tracked top-level files, license and notices, and CI file. Confirm current local author is `Zcxssxx`, there is no remote, and every commit has an actual user-approved author identity.
- [ ] Review the commit history for more than ten meaningful, non-empty changes with normal timestamps; record any shortfall honestly.
- [ ] Review source scope against the design acceptance table and mark each test/doc/demo/security item pass, fail, or pending evidence.
- [ ] Refresh the contest submission-material checklist from the formal charter. Prepare but do not submit any application. Keep items from inaccessible sources marked `待确认`.
- [ ] Commit the final local verification record only if it adds useful reproducible evidence: `docs: record local release readiness`.

**Acceptance:** all locally supported commands have recorded results; unresolved platform, dependency, rule, or hosted-CI items are explicit; local completion is not confused with remote repository or CI completion.

## Commit Milestones

The design and planning commit already exists. The implementation should naturally produce at least these non-empty milestones if each deliverable is completed:

1. `feat: scaffold TrackShield MoonBit module`
2. `test: establish GPX parser compatibility gate`
3. `feat: define TrackShield API and diagnostic model`
4. `feat: reject unsafe and oversized GPX input`
5. `feat: inspect GPX tracks and metadata`
6. `feat: add robust geographic calculations`
7. `feat: find repeated endpoints across GPX collections`
8. `feat: report GPX metadata exposure safely`
9. `feat: render deterministic privacy-safe reports`
10. `feat: add deterministic audit CLI`
11. `feat: preview explicit-zone GPX redaction`
12. `feat: redact GPX data without bridging removed areas`
13. `feat: add preview-first redaction CLI`
14. `test: cover GPX privacy and redaction edge cases`
15. `docs: document TrackShield workflows and provenance`
16. `ci: add MoonBit quality checks`

Combine milestones only when a reviewer would consider the deliverables one coherent change; never manufacture a commit to satisfy the count.

## Specification Coverage Review

| Approved specification requirement | Plan task(s) |
|---|---|
| GPX 1.0/1.1 parser and dependency safety | 1, 2, 5, 14 |
| Deterministic directory and explicit path input, limits, partial errors | 4, 10, 14 |
| First/last track endpoints; route exclusion; distinct source file threshold | 5, 7, 14 |
| Geodesic proximity, transitive chains, center and spread | 6, 7, 14 |
| Metadata categories and no raw values | 5, 8, 9, 14 |
| Stable text/JSON with coordinate opt-in | 7, 9, 10, 14 |
| Explicit-zone preview and redaction, segment splitting, selected metadata | 11, 12, 13, 14 |
| No overwrite, safe output, reparse, destination diagnostics | 12, 13, 14 |
| CLI error and exit-code semantics | 10, 13, 14 |
| Local-first, no network, privacy limitations | 3, 4, 9, 10, 11, 13, 15 |
| Tests, examples, README, OSI license, provenance | 2, 14, 15 |
| CI, toolchain, formats, generated public interface review | 1, 16, 17 |
| Meaningful source and commit targets without padding | 17, Commit Milestones |
| Current hackathon submission materials and exact rules | 1, 17 |

## Plan Self-Review

- Spec coverage: every numbered design goal, acceptance criterion, safety property, and maintenance target maps to one or more tasks above.
- Placeholder scan: there are no unspecified implementation steps, unresolved type names in the planned TrackShield API, or tests described only as “test the above.” Dependency-specific details are gated on the explicit probe task.
- Type consistency: audit methods consume `GpxInput`, `InputLimits`, `FileInspection`, and `AuditOptions`; reports use `EndpointEvidence` without coordinates unless the optional `center` is enabled; redaction methods consume only `GpxInput`, `RedactionOptions`, and `InputLimits`, and return a preview or `Result[RedactedFile, Diagnostic]`.
- Current evidence limits: the landing page reports an October 31, 2026 registration/acceptance deadline, but its update timestamp is not displayed. The official charter and supplemental pages were inaccessible to current page retrieval; their licensing, Mooncakes, CI, and precise toolchain clauses remain unconfirmed until Task 1.

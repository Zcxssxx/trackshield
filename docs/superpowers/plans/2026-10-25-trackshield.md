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
pub struct MetadataFinding { source_path: String, category: MetadataCategory, item_ordinal: Int, occurrence_count: Int }
pub struct FileInspection { source_path: String, endpoints: Array[EndpointObservation], metadata_findings: Array[MetadataFinding], diagnostics: Array[Diagnostic], track_count: Int, point_count: Int, analyzed: Bool }
pub struct AuditOptions { radius_m: Double, min_distinct_files: Int, include_coordinates: Bool }
pub struct EndpointEvidence { source_path: String, track_ordinal: Int, kind: EndpointKind, observation_index: Int }
pub struct RepeatedLocation { id: String, distinct_file_count: Int, distinct_track_count: Int, evidence: Array[EndpointEvidence], center: GeoPoint?, max_distance_from_center_m: Double, wide_component: Bool }
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
- [ ] `moon test geo --deny-warn` is still blocked by five later audit/redaction result records (`EndpointEvidence`, `RepeatedLocation`, `AuditReport`, `RedactionPreview`, `RedactedFile`) that remain intentionally unconstructed until their producer tasks. Ordinary geometry tests pass 11/11; no geometry warning is present.
- [ ] Commit: `feat: add robust geographic calculations`.

**Acceptance:** numerical tests pass on the native target; distances use metres and the mean Earth radius, while runtime radius comparisons are inclusive and exact (`distance_m <= radius_m`). The 1 cm tolerance is only for numerical reference assertions.

### Task 7: Aggregate repeated endpoints across distinct files

**Files:** `audit/moon.pkg`, `audit/endpoint_graph.mbt`, `audit/clusters.mbt`, `audit/cluster_test.mbt`, `api/api.mbt`.

**Interfaces:** `audit_collection(inspections: Array[FileInspection], options: AuditOptions) -> AuditReport`; each connected component is qualified by distinct file count, while distinct track count is reported separately.

- [ ] Add tests where three separate files qualify, two separate files do not qualify, many tracks in one file count as one source, duplicate endpoints from one track count as observations but not files, repeated canonical paths count as one source, and file input order permutations produce byte-stable findings. The CLI canonicalizes file paths before inspection; direct library calls use the exact normalized `source_path` string as the source identity.
- [ ] Add tests for a pairwise-near transitive chain whose component radius is wider than the configured radius; set `wide_component = true`, retain all evidence, and add a stable `audit.wide_endpoint_component` warning.
- [ ] Add tests for identical endpoints, no endpoints, invalid coordinates in one inspection, duplicate paths, and a component exactly at the configured distance.
- [ ] Implement a deterministic spatial proximity graph using the geo package. Sort observations by stable source path, track ordinal, kind, and observation index before assigning stable finding IDs.
- [ ] Omit the center unless `include_coordinates`; always report distinct files, distinct tracks, evidence references, max center distance when a stable center exists, and the chained/wide flag.
- [ ] Run `moon test audit --deny-warn` and `moon test --deny-warn`.
- [ ] Commit: `feat: find repeated endpoints across GPX collections`.

**Acceptance:** repeated-location findings are reproducible under input reordering, respect distinct-file thresholds, and never label a location or person.

### Task 8: Add safe metadata audit aggregation

**Files:** `audit/metadata.mbt`, `audit/metadata_test.mbt`, `api/api.mbt`.

**Interfaces:** Metadata findings are aggregated by stable path/category/item ordinal; values remain absent from the public metadata report.

- [ ] Add tests for every category in `MetadataCategory`, including per-point timestamp coverage with zero, partial, and complete timestamp presence.
- [ ] Test that identical field values in different files yield separate path evidence and that field text, email, URL, timestamp, and coordinates never appear in the serialized finding.
- [ ] Test that duplicate entries in `remove_metadata` or category aggregation do not double-count one source field.
- [ ] Implement deterministic metadata aggregation and stable diagnostic merge. Do not include values even when a parse error occurs.
- [ ] Run `moon test audit --deny-warn`.
- [ ] Commit: `feat: report GPX metadata exposure safely`.

**Acceptance:** all spec categories are represented, counts are explicit, order is stable, and sensitive values are not retained in report records.

### Task 9: Render stable text and JSON reports

**Files:** `report/moon.pkg`, `report/text.mbt`, `report/json.mbt`, `report/report_test.mbt`, `api/api.mbt`.

**Interfaces:** `render_text(AuditReport) -> String`; `render_json(AuditReport) -> String`. Both render deterministic ordering and omit coordinates unless the report explicitly includes a center.

- [ ] Add golden tests for an empty collection, one cluster with metadata findings, one wide chained component, partial parse diagnostics, and coordinate opt-in.
- [ ] Add JSON escaping tests for quotes, backslashes, newlines, control characters, non-ASCII text, and paths. Parse the resulting JSON using MoonBit core JSON in the test to prove syntactic validity.
- [ ] Add privacy regression tests that search encoded output for fixture coordinate strings, raw metadata name/email/link values, and exact timestamps; expected: no match in default output and only the cluster center appears in coordinate-opt-in output.
- [ ] Implement explicit field order and stable arrays. JSON must use correct escaping and valid numeric formatting; text must include the privacy limitation statement.
- [ ] Run `moon test report --deny-warn`.
- [ ] Commit: `feat: render deterministic privacy-safe reports`.

**Acceptance:** golden outputs are deterministic, syntactically valid JSON, and default reports do not reveal raw values or exact coordinates.

### Task 10: Implement deterministic audit CLI and file traversal

**Files:** `cmd/main/moon.pkg`, `cmd/main/main.mbt`, `cmd/main/args.mbt`, `cmd/main/input_files.mbt`, `cmd/main/audit_command.mbt`, `cmd/main/cli_test.mbt`, `README.md`.

**Interfaces:** Native executable command `trackshield audit <path>... [--radius-m <number>] [--min-files <positive-int>] [--format text|json] [--show-coordinates] [--max-file-bytes <positive-int>] [--max-points <positive-int>] [--max-files <positive-int>] [--max-total-bytes <positive-int>]`; filesystem adapter loads and inspects one file at a time and passes `Array[FileInspection]` to the library.

- [ ] Discover and record exact MoonBit argument-parsing and filesystem APIs with `moon ide doc`; use only documented current signatures. If the async filesystem APIs cannot safely identify symlink/reparse entries, use a supported platform API or reject directory mode for that platform with a clear diagnostic until safely supported.
- [ ] Add CLI tests for help, missing paths, invalid option values, invalid paths, unsupported extensions, unreadable files, empty directories, deterministic nested directory order, symlink/reparse exclusion, and partial-success exit behavior.
- [ ] Test collection boundaries at `max_files` and `max_total_bytes`, then one file and one byte over; excess files receive stable diagnostics and are not parsed.
- [ ] Test each resource-limit CLI option at its default, valid override, malformed value, zero, and negative value; confirm the configured limit reaches the library and directory loader.
- [ ] Implement exit code 0 when all inputs are analyzed regardless of privacy findings, exit code 1 for one or more unanalyzable inputs with a report, and exit code 2 for usage/fatal errors before a report.
- [ ] Test reports written to stdout only; errors and diagnostic summaries go to stderr; no raw metadata values or coordinates are logged.
- [ ] Add runnable audit invocations to README and verify each invocation against the synthetic examples.
- [ ] Run `moon run cmd/main -- --help`, the documented text and JSON commands, `moon test cmd/main --deny-warn`, and `moon build --target native --deny-warn`.
- [ ] Commit: `feat: add deterministic audit CLI`.

**Acceptance:** CLI works against files and directories on the supported native OS, does not follow links by default, and returns the specified exit codes.

### Task 11: Plan redaction for explicit user-supplied circles

**Files:** `redact/moon.pkg`, `redact/preview.mbt`, `redact/options.mbt`, `redact/redaction_test.mbt`, `api/api.mbt`, `docs/privacy-model.md`.

**Interfaces:** `preview_redaction(input: GpxInput, options: RedactionOptions, limits: InputLimits) -> RedactionPreview`; the supplied circle is independent of audit findings. Preview computes exact change counts but writes nothing.

- [ ] Test valid and invalid centers/radii, point inclusion at the radius boundary, dateline and high-latitude inclusion, duplicate metadata category selections, and no-op zones.
- [ ] Test that preview returns counts for track points, new segments, routes, waypoints, and selected metadata; test an input that would become empty.
- [ ] Implement preview from explicit config only. Do not accept a cluster ID as a center or silently reuse audit output.
- [ ] Add a library-level test that calling preview creates no filesystem path; the API package must not import filesystem functionality.
- [ ] Run `moon test redact --deny-warn`.
- [ ] Commit: `feat: preview explicit-zone GPX redaction`.

**Acceptance:** preview is pure, deterministic, and reports all affected object counts without writing or inferring a zone.

### Task 12: Transform track, route, waypoint, and selected metadata safely

**Files:** `redact/transform.mbt`, `redact/metadata.mbt`, `redact/transform_test.mbt`, `gpx/adapter.mbt`.

**Interfaces:** `redact_gpx(GpxInput, RedactionOptions, InputLimits) -> Result[RedactedFile, Diagnostic]`; implementation removes points inside the explicit circle, splits each retained run into distinct segments, filters routes/waypoints, and removes only selected metadata categories.

- [ ] Write failing transform tests for leading, middle, trailing, consecutive, and all-points redacted runs in one segment; boundary points; multiple original segments; route/waypoint removal; and an empty output.
- [ ] Write tests where selected creator/name/author/link/track/route/waypoint/timestamp/extension categories are removed while unselected fields remain unchanged.
- [ ] Write round-trip tests for supported extensions and unknown optional fields. If the dependency cannot preserve an unselected field, return `gpx.lossless_redaction_unsupported` and do not produce bytes that imply successful preservation.
- [ ] Implement track splitting so no output segment bridges a removed run; omit empty tracks/routes and emit diagnostics. Do not output an empty file when all track, route, and waypoint content is removed.
- [ ] Re-parse transformed bytes through the same hardened adapter and validate the supported GPX version, point ranges, and expected removal counts before returning `RedactedFile`.
- [ ] Run `moon test redact --deny-warn` and `moon test --deny-warn`.
- [ ] Commit: `feat: redact GPX data without bridging removed areas`.

**Acceptance:** originals are untouched, every written candidate reparses, and all unselected supported fields/extensions match the input semantically.

### Task 13: Add safe filesystem writes and redaction CLI

**Files:** `cmd/main/redact_command.mbt`, `cmd/main/safe_output.mbt`, `cmd/main/redact_cli_test.mbt`, `README.md`, `docs/formats-and-limits.md`.

**Interfaces:** `trackshield redact <path>... --center LAT,LON --radius-m N [--remove-metadata CATEGORY,...] [--write --output-dir DIR]`. Without `--write`, the command previews only. With `--write`, every destination path is new and is re-parsed before final publication.

- [ ] Test preview mode creates no directory or file; `--write` without `--output-dir`, with existing output dir, with output equal to an input directory, and with output nested under input directory all fail before writing. Test duplicate basenames from separate input directories; reject colliding derived destinations before writing.
- [ ] Test a destination with one valid and one invalid input: failed files are not published as successful outputs and the summary names each diagnostic without leaking source values.
- [ ] Implement path canonicalization and containment checks using confirmed filesystem APIs. Reject symlink/reparse traversal and any destination overlap with inputs.
- [ ] Write to a newly created staging sibling directory, flush and close all files, re-open and re-parse each staged GPX, then rename the staging directory to the requested previously nonexistent destination if the platform API guarantees the operation. If that guarantee is unavailable, use per-file exclusive creation and document partial-write cleanup behavior; never overwrite an existing path.
- [ ] Print exact counts and output paths, with a reminder that cleaned files and reports remain sensitive. Exit 0 for successful preview/write and 2 for usage, path, destination, or I/O errors.
- [ ] Run preview and write examples in temporary directories and compare original file bytes before and after; expected: originals byte-identical.
- [ ] Commit: `feat: add preview-first redaction CLI`.

**Acceptance:** preview has no side effects, write requires explicit confirmation, collisions and input/output overlap are rejected, and generated files are validated before publication.

### Task 14: Complete adversarial, compatibility, and regression tests

**Files:** `testdata/README.md`, `*/*_test.mbt`, `cmd/main/*_test.mbt`, `docs/formats-and-limits.md`.

**Interfaces:** Tests exercise only the public API or one package boundary at a time; expected error cases compare stable diagnostic codes rather than parser-specific prose.

- [ ] Create a synthetic three-file collection whose endpoints form one qualifying cluster and another below-threshold collection. Document that fixtures are authored, synthetic, and contain no real coordinates or personal data.
- [ ] Complete cases from the spec: dateline, high latitude, identical points, exact radius, empty tracks, multi-segment tracks, GPX 1.0/1.1, transitive wide clusters, duplicate file support, sensitive default output, opt-in center, preview no-write, destination collision, segment splits, selected metadata removal, preserved unselected extensions, malformed XML, namespaces, DOCTYPE, external entity, oversized file, and unreadable path.
- [ ] Add property-style deterministic tests: permuting source file order preserves report bytes; running the same operation twice gives identical bytes for audit reports; all output coordinates remain in range; all retained track segments contain only points outside the explicit zone.
- [ ] Add regression tests for each previously observed failure and keep the fixture minimal for the behavior under test.
- [ ] Run targeted tests for each affected package, then `moon test --deny-warn` for the whole module.
- [ ] Commit: `test: cover GPX privacy and redaction edge cases`.

**Acceptance:** every acceptance item in the design specification maps to a named passing test or a documented platform limitation.

### Task 15: Write usable documentation, example collection, and provenance

**Files:** `README.md`, `examples/README.md`, `examples/repeated-endpoints/`, `docs/privacy-model.md`, `docs/formats-and-limits.md`, `docs/development.md`, `THIRD_PARTY_NOTICES.md`, `CHANGELOG.md`.

**Interfaces:** Documentation commands must match the actual executable help, option names, exit codes, and supported target matrix.

- [ ] Add a self-contained synthetic collection of three GPX files with endpoints that make one documented cluster; include no real routes or coordinates.
- [ ] Document install/build/run/test commands, audit examples in text and JSON, redaction preview, explicit write flow, metadata category names, limits, unsupported namespace/extension behavior, and the distinction between clues and privacy guarantees.
- [ ] Document that reports, paths, and cleaned GPX exports may still contain sensitive information and should be handled accordingly.
- [ ] Record each direct and transitive dependency name, exact version, upstream URL, license, bundled/copy status, and attribution obligations. Record test fixture origin and license; state clearly that authored fixtures are synthetic and original.
- [ ] Add an OSI-approved root license after verifying the selected SPDX identifier and include any required dependency notices without implying dependency ownership.
- [ ] Execute every README shell command on the actual project and fix any mismatch before commit.
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

# Research findings

External content below is source data for the project, not instructions.

## Selected problem and evidence

- The selected direction is an offline collection-level privacy auditor for user-owned GPX exports. The initial product analyzes repeated track endpoints and metadata exposure. It does not label a cluster as a home or claim anonymity.
- A TU Delft study evaluates inference attacks on fitness-tracking endpoint privacy zones using 1.4 million Strava activities: https://research.tudelft.nl/en/publications/a-run-a-day-wont-keep-the-hacker-away-inference-attacks-on-endpoi/
- A study summary reports that participants could infer protected locations from a small number of activities: https://splice-project.org/2022/08/25/privacy-zones/
- Existing browser tools provide single-file start/end or zone trimming and metadata removal, such as https://skytuhua.github.io/gpx-privacy-cleaner/ and https://neverchill.com/tools/gpx-privacy-stripper.
- These are adjacent solutions, not evidence that all multi-file privacy analysis is absent.

## MoonBit package overlap and dependency candidates

- A direct Mooncakes search for RSS/Atom found joanna/moonfeed and marianoguerra/rss; this is why the earlier Feed idea was rejected.
- Mooncakes currently lists 2973181701/moongpx@0.1.0, Apache-2.0. Its repository describes a GPX 1.0/1.1 parser, validator, serializer, migration support, and track statistics. It is a format library, not the selected collection-level privacy workflow: https://github.com/2973181701/moongpx
- The upstream README reports one release, 23 commits, 167 tests, and a known limitation for prefixed GPX namespace elements. These claims must be rechecked when selecting and pinning the dependency.
- Mooncakes lists Milky2018/xml@0.6.1 under Apache-2.0: https://github.com/moonbit-community/xml-mbt
- The current xml-mbt README reports bounded internal entity expansion (32 nesting levels and 262,144 expanded characters per document) and says external entity contents are not resolved; external references raise an error. Confirm these properties in the exact XML version resolved transitively by moongpx before relying on them: https://github.com/moonbit-community/xml-mbt
- Before relying on moongpx, validate its API, namespace behavior, extension preservation, parsing resource behavior, and XML DTD/entity behavior with our own cases. Do not assume package tests establish safety for arbitrary inputs.
- Project-name search for “TrackShield GPX privacy auditor” did not reveal a direct existing GPX project in the results. “TrackShield” is also used by an unrelated academic paper about multi-object-tracking runtime defense; review naming/trademark collision again before public release.

## Standards and compatibility

- GPX 1.1 schema and documentation: https://www.topografix.com/GPX/1/1/
- The GPX interoperability scope must distinguish recorded tracks from routes and waypoints. The MVP analyzes track endpoints; route and waypoint handling is limited to metadata review and explicit-zone redaction.

## Search limitations

- Mooncakes searches are useful for current MoonBit package overlap, but a missing result is not proof that no implementation exists anywhere.
- Public GitHub and web queries did not reveal an existing MoonBit collection-level GPX privacy auditor in the searches performed to date. Re-run targeted searches before public release.
- No source code or test fixtures have been copied from the upstream GPX project or third-party privacy tools.

## GPX/XML dependency compatibility gate (2026-10-25)

- `moon view 2973181701/moongpx@0.1.0` reports Apache-2.0 and the project repository `https://github.com/2973181701/moongpx`. The exact release is pinned in `moon.mod`.
- `moon tree --json` resolves `Zcxssxx/trackshield -> 2973181701/moongpx@0.1.0 -> Milky2018/xml@0.4.1 -> moonbitlang/x@0.5.1`. The checked LICENSE files for moongpx and xml are Apache-2.0; `moon view moonbitlang/x@0.5.1` also reports Apache-2.0. `moonbitlang/x@0.5.1` is retained as the exact transitive resolution of xml 0.4.1, not added as a direct dependency.
- Inspected the pinned source API: `@moongpx.parse_gpx(src : String) -> Result[Gpx, Array[Diagnostic]]`, `@moongpx.parse_gpx_any(src : String) -> Result[Gpx, Array[Diagnostic]]`, `@moongpx.to_gpx(gpx : Gpx) -> String`; shared model types include `Gpx`, `Track`, `TrackSegment`, and `Waypoint`. The package's own README says prefixed GPX element names such as `<g:gpx>` are unsupported; default namespace form remains supported.
- Added authored inline probes at `gpx/dependency_probe_test.mbt`. On 2026-10-25, `moon test gpx` exited 0 with 4/4 tests passing: GPX 1.1 default-namespace parse/serialize semantic equality (including an extension payload), GPX 1.0 migration into the shared model, prefixed-root rejection, and malformed XML rejection. No upstream fixtures were used.
- The `moon test gpx` output includes one `unused_package` warning because MoonBit does not count test-file references as production package use. `moon test gpx --deny-warn` and `moon check --deny-warn` therefore do not pass at this intermediate step. Retry both once the production adapter in Task 5 imports and consumes moongpx; do not suppress the warning to hide it.
- `moon ide doc '@moongpx.parse_gpx' --no-check` and queries for `@moongpx.Gpx` and `Bytes::from_array` all returned `Fail to load core: no metadata is available for any backend`. Direct inspection of the pinned source and compiled tests supplied the parser API evidence. Retry IDE docs after a successful full-module check has generated metadata.
- The exact xml 0.4.1 README states UTF-8/XML 1.0 only, bounded internal entity expansion (32 nesting levels and 262,144 expanded characters per document), and no external entity resolution; a reference to an external entity raises an error. Its `Reader` emits DOCTYPE events, so TrackShield will reject all DOCTYPE before parsing regardless of entity behavior.
- Inspection of the pinned moongpx parser shows it builds a complete node tree and has no TrackShield-configurable XML element-depth cap. Add a TrackShield preflight depth and element-count limit before calling it. The configured per-file byte limit also bounds text input; the parsed point-count limit is applied immediately after parse, and the additional XML element cap bounds non-point-node allocation.
- Known compatibility boundary: GPX 1.0 and 1.1 with unprefixed/default namespace forms are accepted by the current parser probes; prefixed element names are rejected and will receive a stable TrackShield diagnostic. Extension payload preservation is verified for a synthetic GPX 1.1 point extension in the round-trip test. Broader vendor extension constructs remain `待确认` until real, redistributable examples are evaluated.
- Official Topografix references identify the GPX 1.1 target/default namespace as `http://www.topografix.com/GPX/1/1` ([1.1 schema documentation](https://www.topografix.com/gpx/1/1/)) and show GPX 1.0 examples using `http://www.topografix.com/GPX/1/0` ([1.0 developer manual](https://www.topografix.com/gpx_manual.asp)). The authored GPX 1.0 fixture was corrected to use its official URI. Preflight accepts absent namespaces as a compatibility form, accepts only those two explicit URIs, requires version/URI agreement when both are present, and rejects prefixed core elements the dependency would otherwise ignore.

## Public model/API implementation notes

- The current official MoonBit [package and access-control documentation](https://docs.moonbitlang.com/en/latest/language/packages.html) defines `pub struct` as readonly outside its package and `pub(all)` as freely constructible. TrackShield uses readonly public records for validated coordinates/options/results and `pub(all)` only for enums whose variants must be selected by library callers.
- The `api` package uses `pub using @model { ... }` to re-export the documented types, diagnostic code values, and validated constructors. `moon info --package api` shows these re-exports and the constructor signatures in `api/pkg.generated.mbti`.
- Current `InputLimits` adds `max_xml_depth` and `max_xml_elements` to the earlier API sketch. Hard maxima are 256 nesting levels and 2,000,000 XML elements; defaults are 128 and 500,000. Other hard ceilings are 64 MiB per file, 1 GiB total bytes, 5,000 files, and 1,000,000 GPX points per file. Default limits are 32 MiB/file, 256 MiB total, 500 files, and 250,000 points/file.
- The redaction-options constructor copies the caller's mutable metadata-category array before storing it. Callers should treat arrays reachable through readonly result records as snapshots; consumers must still take local copies before mutating collections.
- `Diagnostic::to_string` emits only the stable code and message; it omits `path`. Internal diagnostics must continue using static or sanitized messages and never interpolate source names, metadata, coordinates, timestamps, or XML text.

## XML preflight implementation gate

- Implemented `internal/xmlguard.validate_input` and `preflight_xml` as an internal package. The byte-length check runs before lexical scanning; XML scanning is limited to the already bounded byte buffer and validates UTF-8, XML declaration encoding, root/version namespace, matching tag nesting, maximum depth, and element count.
- The scanner distinguishes comments, CDATA, processing instructions, quoted attribute values, and markup before looking for a real DOCTYPE. It rejects DOCTYPE before any GPX semantic parser is called; it performs no filesystem or network access. Diagnostics use stable codes/static messages and do not include document bytes.
- Supported root forms currently include unnamespaced GPX for compatibility and the official GPX 1.0/1.1 default namespace URIs. Core prefixed elements are rejected except prefixed extension payloads within `<extensions>`; the pinned dependency's exact prefix behavior remains recorded in the compatibility probes.
- At the pre-adapter stage, `moon test internal/xmlguard` passed 13/13 for size boundaries, DTD lexical cases, encoding/UTF-8, malformed structure, depth/element limits, namespace/version checks, and extension-prefix handling. Task 5 below adds a GPX point-count limit and public-call-path coverage.
- At the pre-adapter stage, warning-denial reported eight future result-record warnings and the not-yet-used pinned GPX dependency. Task 5 now consumes the dependency and reduces the warning set to five planned audit/redaction result records; public preflight-before-parser coverage is implemented. Neither warning nor error is suppressed.

## GPX adapter behavior

- The new `api.inspect_gpx(input, limits)` is the sole current semantic-parse entry point. `gpx.inspect_gpx` calls `internal/xmlguard.validate_input` first, strictly decodes UTF-8 with `moonbitlang/core/encoding/utf8`, strips an already-validated BOM, and only then invokes `moongpx.parse_gpx_any`. Preflight and point-limit failures produce no partial model; parser error details are intentionally replaced by a static `gpx.parse_failed` message.
- Point limits count standalone waypoints, route points, and track points. XML preflight recognizes only the GPX core names `wpt`, `rtept`, and `trkpt` outside extension payloads, so a limit violation is rejected before the parser builds a document model. A post-parse count check remains as a consistency guard.
- `FileInspection.point_count` covers all three GPX point forms. Routes and standalone waypoints are included in metadata detection and point limits but never create start/end observations. Each non-empty track yields the first point of its first non-empty segment and the last point of its last non-empty segment; 1-based track ordinals and zero-based file-local observation indexes preserve stable identity.
- Metadata findings contain only a category, 1-based ordinal, and occurrence count. Link and extension ordinals advance deterministically within one file; point name/description/timestamp findings use a 1-based point ordinal. No creator, metadata, author, URL, timestamp, or extension value is copied into `MetadataFinding`.
- Task 5 validation currently passes `moon fmt --check`, `moon check` (5 expected future-record warnings, 0 errors), `moon build --target native`, full `moon test` (39/39), and `moon info --package model`/`api`. Package counts are xmlguard 14/14, gpx 5/5, model 10/10, and api 10/10. Warning-denial reports only five result records awaiting audit/redaction producers; the GPX package is no longer unused. No warning is suppressed.

## Geographic calculation policy

- Distances use the haversine central angle on a sphere with the IUGG mean-Earth radius `6,371,008.8 m`. Longitude deltas are normalized to the shortest signed range before conversion to radians, and the haversine value is clamped to `[0, 1]` against floating-point drift.
- Runtime threshold comparisons are inclusive and use the computed metre distance directly: an edge qualifies when `distance_m <= radius_m`; no epsilon is added to the user-configured radius. The numeric reference tests use one absolute tolerance of `0.01 m`.
- Spherical means sum unit vectors and convert the normalized resultant back to geographic coordinates. Empty inputs and resultants no larger than `1e-12 * point_count` return `geo.undefined_center`; they do not select an arbitrary coordinate. At a numerically exact pole the reported longitude is normalized to zero.
- Task 6 ordinary tests pass 11/11, the full suite passes 50/50, `moon fmt --check`, ordinary `moon check`, and `moon build --target native` pass. `moon test geo --deny-warn` and full warning-denial remain blocked only by the same five future audit/redaction result-record warnings; no geometry warning is reported.

## Current October 2026 competition check

Checked 2026-10-25 against the current [2026 MoonBit Hackathon landing page](https://moonbitlang.github.io/Hackathon2026/). The page search result identifies the event as the October round and states a 2026-10-31 registration and acceptance deadline. No “last updated” date was visible in the retrieved page content.

### Landing-page requirements stated for this round

- The October round permits at most three submissions. The last valid submission or modification before approval is used; a rejected project may be revised.
- The public submission flow asks for competition information, a public repository, and a one-page project description.
- Qualification review is rolling.
- Development should remain visible in a public repository with ongoing commits and project activity; acceptance asks for code, README, tests, and reproducible demonstration instructions.
- MoonBit must be the primary implementation language; the repository must be publicly accessible; open-source compliance and explainable AI-assisted work are part of the landing-page acceptance criteria.
- The page says participants must join the event group and use their GitHub ID as the group nickname for prize administration. This is an event administration statement, not authorization to perform GitHub operations now.
- The page recommends a clear project boundary and verifiable delivery; listed project directions are suggestions, not an exhaustive restriction.

### Awaiting primary-source confirmation

- User-provided formal charter: https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd
- User-provided supplemental event page: https://bxup9uklfcb.feishu.cn/wiki/KNrVwEVFziPHiGkQtwhc6w3gndd
- Current page retrieval could not expose either Feishu document's body. Their update timestamps, full application materials, review/modification details, exact license requirements, Mooncakes publication requirements, CI requirements, and toolchain-version clauses remain `待确认`.
- Do not infer 2026 Hackathon requirements from OSC 2026, the August Hackathon, or another competition. Re-open these sources before preparing the final application package.
- The installed toolchain on 2026-10-25 is `moon 0.1.20261023 (3778465 2026-10-23)`, `moonc v0.10.17+d971670cd (2026-10-23)`, and `moonrun 0.1.20261023`. An official latest-stable comparison has not yet been recorded.
- The official [MoonBit download page](https://www.moonbitlang.com/download/) describes installing the “latest moonbit toolchain” and provides `/binaries/latest/` checksum URLs, but the page does not print the corresponding version number. The official [updates page](https://www.moonbitlang.com/updates) retrieved in this check has no match for `0.10.17` or `20261023`; the latest-stable comparison is therefore still `待确认`, not inferred from the local binary timestamp.
- The official download page says the supported Windows installation route is the VS Code “MoonBit:install latest moonbit toolchain” command or the PowerShell installer. Do not run a machine-wide installer unless an update is proven necessary and permitted by the workspace boundary.

## Scaffold probe

- A temporary `moon new <path> --user Zcxssxx --name trackshield` probe showed the current template uses a root package, `cmd/main`, `moon.mod`, `moon.pkg`, root Apache-2.0 `LICENSE`, `.gitignore`, root `README.mbt.md`, tests, and a Copilot setup workflow. It also initializes a `.git` directory; only selected template content should be adapted into the existing repository.
- On this Windows host, the template's `README.md -> README.mbt.md` symlink creation failed with OS error 1314. TrackShield will use a regular `README.md` and update `moon.mod` accordingly.
- The first cleanup attempt on the temporary template encountered Windows access errors. The exact temp path was revalidated under `%TEMP%`, removed using `Remove-Item -Force -Recurse`, and its absence verified.
- The actual module files were created manually without running `moon new` in the existing repository. `moon check --deny-warn` passed, and `moon run cmd/main` printed `TrackShield`.

### Local tool behavior checked

- Current help confirms `moon fmt --check`; `moon check`, `moon build`, and `moon test` support `--deny-warn`; `moon info` has no `--deny-warn` option.
- Current help lists native, wasm-gc, js, wasm, and llvm target selectors for check/build/test. Actual TrackShield target support depends on the resolved dependencies and CLI boundary.
- `moon new --help` lists a dry-run flag, but a prior actual dry-run invocation returned `Error: dry-run is not supported for new`. The failed probe did not scaffold files; use an inspected temporary scaffold rather than relying on dry-run.

## Repeated endpoint aggregation

- `audit_collection` treats `FileInspection.source_path` as the normalized identity for every endpoint in that inspection. This keeps direct library calls deterministic and prevents inconsistent embedded endpoint paths from inflating distinct-file support.
- Candidate edges use a 3D Earth-centered spatial grid. The bucket width is the spherical chord corresponding to the configured radius, with a small numerical discovery margin and a 1 mm lower bound. A haversine check with the user radius remains the final inclusive edge rule; grid proximity never decides a finding by itself.
- The chord angle is clamped at π because the validated option maximum (half the equatorial circumference) is slightly larger than π times the mean Earth radius used by `geo.distance_m`. Without this clamp, a maximum-radius search could miss an antipodal pair.
- Union-find forms transitive components. A chain may therefore span farther than one radius; stable spherical-mean spread marks such a component `wide_component` and adds `audit.wide_endpoint_component`. It remains evidence of repeated endpoints, never a home/work inference or proof of anonymity.
- Component order is determined by sorted source path, track ordinal, endpoint kind, observation index, then coordinates. Evidence preserves only source path, track ordinal, kind, and file-local observation index. Distinct tracks are counted by `(FileInspection.source_path, track_ordinal)`; distinct files by exact `FileInspection.source_path`.
- The center is disclosed only when `include_coordinates` is true. Its maximum spread is still available when the center is hidden. If the spherical mean is unstable, both center and max spread are absent, `geo.undefined_center` is added, and `wide_component` remains false because the radius cannot be computed.
- `moon test audit` passes 11/11, the public API test passes 11/11, and full native tests pass 62/62. Formatting, ordinary check, native build, and API/model interface generation pass. Warning-denial is currently blocked only by the two result records reserved for the later redaction task.

## Metadata aggregation and timestamp coverage

- `MetadataFinding` intentionally contains only `source_path`, `category`, `item_ordinal`, and `occurrence_count`. The collection audit rewrites its path from the enclosing `FileInspection.source_path`, so a malformed or repeated embedded path cannot change source identity.
- Findings are keyed by exact path/category/item ordinal and sorted by that same stable order. Duplicate identities are represented once; if duplicate counts differ, the larger count is retained rather than summed. Different paths with identical GPX metadata remain separate findings.
- Every parsed GPX point now produces a `PointTimestamp` coverage fact: `occurrence_count = 1` when time is present, `0` when absent. Its ordinal is 1-based in the same combined point order used by `FileInspection.point_count`, covering standalone waypoints, route points, and track points. Exact timestamp strings are never copied.
- Aggregation rejects nonpositive ordinals, nonpositive ordinary-category counts, negative timestamp counts, and timestamp ordinals beyond the file's point count. It omits the malformed record and adds a static `audit.invalid_metadata_finding` warning. Findings from `analyzed = false` inspections are excluded while their existing diagnostics are preserved.
- `moon test audit` passes 17/17, `moon test api` passes 14/14, and the complete native test suite passes 71/71. Formatter, ordinary check, native build, and audit/API/model interface generation pass. Warning-denial reports only the two result records not constructed until redaction work.

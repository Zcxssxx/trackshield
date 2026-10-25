# TrackShield design specification

**Status:** Approved direction; written specification is awaiting user review.

## 1. Problem

Outdoor athletes, hikers, cyclists, and contributors who publish GPS activity files may already hide a start point in a fitness service or trim an individual file. A collection of otherwise harmless exports can still expose recurring locations. File metadata can also contain names, descriptions, author information, timestamps, links, or device-specific extensions.

Research on fitness-tracking privacy shows that endpoint protection does not remove every inference path across multiple activities. TrackShield gives a user a local, explainable way to inspect their own GPX collection before sharing selected files.

## 2. Product and users

TrackShield is a local-first command-line application with a reusable MoonBit library. A user points it at a collection of GPX files and receives evidence about repeated track endpoints and exposed metadata. The user can then preview a redaction using an explicitly supplied geographic circle and choose whether to write cleaned copies to a new directory.

The product describes observations such as “these endpoints from four files fall within the configured distance.” It does not identify a person, infer a home or workplace, or certify privacy.

## 3. Goals

1. Read collections of GPX 1.0 and GPX 1.1 files without network access.
2. Find recurring start/end locations across distinct source files with deterministic, configurable spatial thresholds.
3. Show which files and track endpoints support each finding while withholding exact coordinates by default.
4. Detect a documented set of potentially identifying GPX metadata fields without printing their values by default.
5. Preview and optionally apply redaction for a user-entered center and radius. Preserve originals and write only to a new destination.
6. Produce stable text and JSON reports suitable for terminal review and CI or scripting.
7. Expose the audit and redaction logic as a reusable MoonBit API.
8. Provide real tests, examples, error diagnostics, provenance, and CI.

## 4. Non-goals for the first release

- Identifying an endpoint as a home, workplace, or person.
- Claiming anonymity, preventing all re-identification, or providing a legal privacy assessment.
- Downloading maps, geocoding coordinates, contacting a fitness service, or uploading a user's files.
- Connecting to a GPS device, editing the source application, or modifying original files.
- Map rendering or a graphical interface.
- Night-time dwell inference, behavioral profiling, route recommendation, or social-network analysis.
- Processing KMZ, FIT, TCX, or other formats.
- Automatically redacting a location inferred by the audit.

## 5. First release behavior

### 5.1 Input collection

- Accept explicit GPX file paths and a directory input. Directory traversal is deterministic and limited to GPX files; do not follow symbolic links or Windows reparse points by default.
- Support GPX 1.0 and 1.1 when the selected parser can preserve the supported data model.
- Treat each source file as a distinct activity source for the minimum-activity threshold. A file may contain multiple tracks; it contributes at most once to a location cluster's distinct-file count.
- For each non-empty track, record the first point of its first non-empty segment and the last point of its last non-empty segment.
- Do not treat planned routes as recorded activity endpoints. Routes and waypoints may still produce metadata findings and are considered by explicit-zone redaction.
- Report malformed, unsupported, oversized, empty, or unreadable inputs by path with stable diagnostic codes; continue with independent files.

### 5.2 Collection audit

- Default endpoint radius: 500 metres.
- Default minimum support: three distinct source files.
- Both values are configurable and included in the report.
- Build a graph whose vertices are track start/end observations and whose edges connect observations at or below the configured geodesic distance. Each connected component with enough distinct source files is reported as a repeated-location clue, not a circular guarantee. Components can grow through transitive neighbors; report the component's spherical-mean center only when coordinates are requested, plus its maximum distance from that center, and warn when this radius exceeds the configured threshold.
- Count distinct source files and distinct tracks separately so multiple tracks in one input file cannot inflate the distinct-file threshold.
- Include the source file, track ordinal, endpoint kind, and stable observation index for each finding.
- Do not include exact coordinates or raw metadata values in default text or JSON reports. An explicit coordinate-output option may reveal the cluster center and is clearly described as sensitive.
- Metadata checks in v1 cover GPX creator, metadata name/description, author name/email, links, track names/descriptions, route names/descriptions, waypoint names/descriptions, per-point timestamp presence/coverage, and presence of extensions. Findings name the field category and file but do not echo values or exact timestamps by default.
- Text and JSON formats use stable key ordering and deterministic file ordering.

### 5.3 Explicit-zone redaction

- The user supplies a center latitude/longitude and radius in metres. Audit findings never populate these parameters automatically.
- Default mode is preview-only. The preview reports the affected input files, counts of affected points, metadata fields selected for removal, and outputs that would be written.
- Writing requires an explicit write option and a new output directory. Existing inputs are never overwritten. Existing output paths cause a diagnostic instead of replacement.
- Remove track points inside the circle. If removed points split a continuous track, emit separate track segments so the output does not invent a line across the redacted area.
- Remove route points and waypoints inside the circle.
- Optional metadata removal is selected by explicit field categories. Unselected fields and GPX extensions are preserved where the parser supports lossless preservation.
- If redaction empties a track or route, omit that empty structure and report it. If no track, route, or waypoint remains in a file, skip writing that file and report an empty-result diagnostic; never emit an empty cleaned copy without an explicit future design change.
- Re-parse and validate every written output before reporting success.

## 6. User interface

The CLI has two primary commands:

- audit: inspect one or more files or a directory; accept radius, minimum distinct files, report format, coordinate display, and resource-limit options. Return exit code 0 when all inputs were analyzed, regardless of privacy findings; return 1 if one or more inputs could not be analyzed while still producing the partial report; return 2 for usage or fatal errors before a report can be produced.
- redact: preview or write copies for an explicit geographic circle; accept field-removal options and output directory. Preview is the default; writing requires an explicit write flag. Return 0 for a completed preview/write and 2 for usage, destination, or I/O errors.

The library provides pure collection-audit and GPX-transform operations. Filesystem traversal, argument parsing, and writing stay in the CLI boundary. Public API names and exact type signatures will be fixed in the implementation plan after the upstream dependency is exercised in a minimal prototype.

## 7. Architecture and dependencies

- MoonBit is the primary implementation language.
- Separate the library into input normalization, activity extraction, metadata findings, endpoint grouping, redaction planning/transformation, report model/rendering, and CLI filesystem handling.
- Evaluate 2973181701/moongpx@0.1.0, Apache-2.0, as the GPX model/parser/serializer dependency. Its documented responsibilities overlap the GPX format layer, while TrackShield adds collection-level privacy analysis and a safe workflow.
- Before adopting it, verify GPX 1.0/1.1 behavior, public API availability, namespace handling, extensions round-tripping, malformed-input behavior, limits, and DTD/entity behavior for the dependency version actually resolved. The upstream README currently documents a limitation for prefixed GPX namespace elements. Default-namespace files are in the initial compatibility target; prefixed forms must fail with a precise diagnostic until explicit support is added.
- Preserve upstream attribution and license notices for the dependency. Do not copy upstream implementation or test fixtures. Author TrackShield's test GPX data or document each fixture's source and license.
- Keep the core library free of network and filesystem APIs so it can be built for native and a supported WebAssembly target. The first user-facing executable is a native CLI.

## 8. Safety, privacy, and errors

- Audit operations are read-only.
- All processing is local. The program has no telemetry or network calls.
- Apply conservative file-count, byte-size, and point-count limits, with clear per-file errors. Exact defaults will be set after representative benchmarks.
- Treat XML as untrusted input. GPX does not require a DTD, so reject documents containing a DOCTYPE before semantic GPX parsing. Verify the resolved parser's external-entity behavior, bounded internal entity behavior, malformed encodings, deeply nested elements, and oversized tokens before release. No external resource may be fetched or read.
- Never panic on user input. Convert parse, range, I/O, destination-collision, and unsupported-field failures into structured diagnostics and meaningful exit codes.
- Do not log raw coordinates or metadata values at normal verbosity. Reports and cleaned files are still sensitive artifacts; documentation must explain this.
- Redaction uses an explicit circle and point-removal semantics. It does not promise that remaining routes cannot identify the user.

## 9. Testing and acceptance

The first release is acceptable when:

1. A checked-in synthetic collection with three distinct files and endpoints within the configured distance produces one repeated-location finding with stable evidence.
2. A collection below the distinct-file threshold produces no cluster finding, and duplicate tracks in one file count as one source file.
3. Dateline, high-latitude, identical-point, exact-radius, empty-track, multi-segment, GPX 1.0, and GPX 1.1 cases have explicit tests.
4. A chain of pairwise-near endpoints wider than the configured radius is surfaced as a chained/wide component.
5. Default reports omit exact coordinates and raw metadata values; the opt-in coordinate mode includes them.
6. Preview mode writes no output. Write mode leaves originals byte-for-byte untouched, rejects destination collisions, and produces outputs that parse and validate.
7. Redacted track gaps become separate segments; route points and waypoints inside the explicit zone are removed; selected metadata fields are removed while unselected extensions remain intact.
8. Malformed XML, unsupported namespaces, documents with a DOCTYPE, external-entity references, oversized files, and permission errors yield deterministic diagnostics rather than process crashes, file disclosure, or network access.
9. The native CLI runs from documented examples. The library and tests build on the selected supported target matrix.
10. CI runs formatting, warning-denying checks and tests, target builds, and the documented example. Toolchain version matches the current stable toolchain and current hackathon requirements at implementation time.

## 10. Project quality and maintenance targets

- Continue the user's target of at least 3,000 meaningful MoonBit source lines across production code and tests. Expand only through justified capabilities such as policy configuration, explainable rule sets, report consumers, or collection comparison; do not optimize for line count alone.
- Make more than ten meaningful commits as real development work is completed. No empty commits, artificial history, or backdated timestamps.
- Keep README instructions executable, document supported formats and limitations, include an OSI-approved root license, and record third-party source/data licenses.
- Keep Git local until the full local implementation and verification phase is complete. No remote is configured in this repository.

## 11. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Repeated trailheads create false positives | Use neutral “repeated endpoint” language, require distinct files, show evidence and spread, and never infer a home. |
| Transitive spatial grouping merges a long chain | Report component diameter and warn when it exceeds the configured radius; test adversarial chains. |
| GPX package omits namespace or extension data | Verify against authored fixtures; reject unsupported input clearly; do not claim data preservation unless tests prove it. |
| XML parser behavior is unsafe or unbounded | Gate dependency adoption on adversarial XML tests and explicit resource limits. |
| Redaction creates an artificial line or removes too much | Preview counts, split segments at removed runs, require explicit zone and write confirmation, re-parse output. |
| Reports themselves expose sensitive information | Omit exact coordinates and raw values by default; document report sensitivity. |
| User assumes a clean report means anonymous data | Repeat the limitation in CLI help, report footer, README, and examples. |

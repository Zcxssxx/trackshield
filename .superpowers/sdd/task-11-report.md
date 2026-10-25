# Task 11 implementation report

Status: implemented and verified, with the previously known Task 12 warning
preventing the required warning-strict test command from completing.

Base commit: `83a19d10f3e6f7e90e804528faff81b1da954949`.
Local commit message: `feat: preview explicit-zone GPX redaction`.
Author and committer: `Zcxssxx <Zcxssxx@users.noreply.github.com>`.

## Implemented behavior

- Added `redact/preview.mbt`, `redact/options.mbt`, package configuration and 13
  focused black-box tests. Preview accepts only the existing explicitly supplied
  `RedactionOptions`; it has no audit/cluster input and infers no zone.
- Added `api.preview_redaction` and its intentional generated interface entry.
  The API remains filesystem-free.
- Extracted the existing bounded GPX parser into `gpx.parse_input`, reused by
  inspection and preview. It retains byte/point/depth/element limits, UTF-8/BOM
  handling, namespace/DOCTYPE checks, GPX 1.0/1.1 support, and static safe parse
  diagnostics. It is not re-exported through the API facade.
- Added the narrowly necessary model preview constructor, which snapshots its
  diagnostic array. Existing types and validated options remain compatible.
- Added `docs/privacy-model.md`, defining all count semantics and limitations.
- Added a separate integration-test package under `tests/preview_purity` whose
  test observes an empty temporary directory and nonexistent source path before
  and after a real API preview. No source path, parent directory, or output file
  is created. Filesystem imports exist only at this test boundary.

## Exact count semantics

- `points_removed` includes track points, route points and standalone waypoints.
- `segments_created` counts additional retained runs beyond one per original
  segment. No-op zones, leading/trailing removals and fully removed segments add
  zero. Separate original segments are counted independently.
- `routes_removed` counts routes omitted because no route points remain.
- `waypoints_removed` counts removed standalone waypoints, also included in the
  total point count.
- Metadata counts present selected fields on retained objects and document-level
  metadata. Duplicate category choices do not multiply counts, absent fields
  count zero, and fields lost with removed parent objects are not counted again.
  Extensions count by source container, including once per retained original
  segment even if that segment splits; links count individually.
- Empty output means no retained track/route point or standalone waypoint,
  regardless of remaining document metadata. Empty tracks/routes and empty
  results produce static diagnostics. Failed inputs return zero counts and
  `output_would_be_empty = false`, since their outcome is unknown.

## TDD RED / GREEN evidence

1. Authored the focused tests before implementation and supplied only an aborting
   `preview_redaction` placeholder to make the intended interface executable.
2. Ran `moon test redact` before implementing preview. It failed at the first
   real preview invocation, the no-op test, with:

   ```text
   Task 11 preview not implemented
   PanicError
   The test executable exited with exit code: 0xc0000409
   Active test at executable exit:
     redact/redaction_test.mbt:19
     "no-op preserves separate segments and creates no additional segments"
   ```

   This failure was the deliberate unimplemented-operation placeholder, not a
   missing dependency or unresolved symbol. Initial unused import warnings
   disappeared when the real implementation used the imported packages.
3. Implemented the guarded parser reuse, geometric count traversal, metadata
   counting, model constructor and facade. The first compiling run passed 9 of
   11 tests. Two authored fixtures required correction: GPX child order requires
   `time` before `name`, and the upstream parser rejects an originally empty
   route, so the empty-content fixture uses an empty track instead. These were
   fixture-schema fixes, with no weakening of required behavior.
4. Reran `moon test redact`: 11/11 passed. Added guarded-input compatibility
   checks and the filesystem-observation integration test; final targeted result
   is 13/13 plus 1/1 integration test. An intermediate generic syntax error and
   missing async test import were corrected before final verification.

The tests exercise valid/invalid centers and radii, NaN/infinite values, inclusive
boundary and just-outside points, dateline and polar inclusion, leading/middle/
trailing/consecutive/all-point removals, multiple original segments, no-op zones,
route/waypoint effects, all metadata categories, duplicate selections, retained
versus removed parent metadata, empty output, deterministic repeated calls,
unchanged caller bytes/options, safe malformed-input diagnostics, byte/point
limits, mixed namespaces, invalid encoding, BOM and GPX 1.0 compatibility.

## Final verification

All commands ran locally without GitHub, remote, authentication or network use.

| Command | Result |
| --- | --- |
| `moon fmt` | exit 0 |
| `moon test redact` | exit 0; 13 passed, 0 failed; final output has no warnings |
| `moon test tests/preview_purity` | exit 0; 1 passed, 0 failed; final output has no warnings |
| `moon test` | exit 0; 102 passed, 0 failed; final output has no warnings |
| `moon check` | exit 0; 0 errors, 1 previously known warning |
| `moon info` | exit 0; intended generated interfaces reviewed; same known warning |
| `git diff --check` | exit 0; no whitespace errors; Git emits LF-to-CRLF notices |
| `moon test redact --deny-warn` | exit 1; blocked solely by the known `RedactedFile` warning below |

Exact warning-strict diagnostic after formatting:

```text
Error: [0009]
  model/redaction.mbt:48:12
  48 | pub struct RedactedFile {
     |            ^^^^^^^^^^^^
  Error Warning (struct_never_constructed): The struct RedactedFile is never constructed
```

`RedactedFile` is produced by Task 12. No dummy construction or warning
suppression was introduced. Ordinary tests and checks succeed, but the
warning-strict acceptance command is accurately reported as failing.

Generated interface changes are intentional: `api.preview_redaction`, the
supporting `gpx.parse_input` return type and its moongpx import, the model preview
constructor, and the new redact/test package interfaces. No filesystem API or
raw GPX model was added to the facade.

## Concerns and scope boundaries

The known Task 12 warning is the only remaining verification concern. Preview
does not produce redacted bytes or write output; transformation is Task 12.
It preserves the existing spherical distance model and upstream parser's GPX
acceptance rules. Source path labels remain available in structured results,
while default diagnostic rendering omits paths and all messages omit source
coordinates, timestamps, metadata values and upstream parser text.

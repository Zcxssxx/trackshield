# Task 13 report: preview-first redaction CLI and filesystem writes

Base: `239ede0` on `codex/trackshield-development`. Work was local only: no
remote, GitHub, network, authentication or account commands were used.

## Implementation and contract

Implemented `redact <path>... --center LAT,LON --radius-m N
[--remove-metadata CATEGORY,...] [--write --output-dir DIR]`. Both center and
radius are required and validated by the existing model constructors. All
fourteen documented metadata labels map to the existing enum. Duplicate labels
are harmless membership selections. Existing audit behavior remains unchanged.

The command reuses `collect_gpx_paths` for stable bounded discovery and canonical
alias deduplication, `read_bounded_file` for bounded reads, and the hardened
`api.redact_gpx` operation for every candidate. Preview never calls creation or
publication, including when `--output-dir` names a nonexistent parent. It
reports counts and derived basenames; destination checks happen only in write
mode. An unpublishable transformation is also diagnosed during preview.

Write mode requires an explicit flag and a new directory under an existing
parent. It rejects static reparse/link traversal, missing parents, existing
destinations and canonical overlap with any input root/file. Its mapping is
explicit and flat: `<input directories>/name.gpx` -> `<new output>/name.gpx`.
Before staging, it rejects duplicate ASCII-case-insensitive basenames and
unverified portable-name spellings. Output basenames and the directory leaf
must be 1–180 ASCII letters/digits/`.`/`_`/`-`, without trailing dots, dot-only
names or Windows device stems. Unicode ancestor directories work; source leaf
names containing spaces/Unicode must be renamed by the user before exporting.
UNC, device, drive-relative, alternate-stream and ambiguous Windows input/output
path spellings are rejected. `.`/`..` ancestor aliases are resolved by realpath.
Containment checks use path-component boundaries rather than raw prefixes.

Every discovery diagnostic rejects the batch, including nested links that
audit can skip with a warning. All source files are read-only. All successful
candidates must exist before publication starts. A new sibling directory named
`DIR.trackshield-stage` is created exclusively; a pre-existing staging path is
left untouched and blocks the write. All stage files use exclusive creation,
explicit sync and close. Each is reopened, compared byte-for-byte with the
candidate, parsed with the shared hardened adapter, and checked for remaining
circle/selected metadata content. No final directory is created if any item
fails this validation.

Final publication uses an exclusive new directory and exclusive per-file
creation, then sync/close and independent final byte/GPX validation. The full
batch is deliberately not described as atomic. Failures during publication can
leave completed and partial sensitive files in the new output directory;
`output.partial_write` returns 2, naming the directory. The CLI never removes
that final directory automatically. It attempts to remove only known staging
files and then the empty staging directory, without recursive production
deletion. A staging cleanup failure returns 2 and names its path. Process
interruption/crash may leave remnants. Counts and paths distinguish prepared
items and completed writes, and every report reminds the reader that cleaned
files and reports remain sensitive. Diagnostics do not print source values or
raw exception/parser details; report paths quote control characters.

## Exact local API/source investigation

Toolchain output:

```text
moon 0.1.20261023 (3778465 2026-10-23)
Feature flags enabled: rr_moon_mod,rr_moon_pkg
```

`moon.mod` pins `moonbitlang/async@0.22.5`. Inspected the actual cached generated
interface and sources, rather than assuming Unix-like behavior:

- `.mooncakes/moonbitlang/async/src/fs/pkg.generated.mbti` confirms
  `kind(StringView, follow_symlink?: Bool)`, `realpath(StringView)`,
  `create(StringView, allow_existing?: Bool, permission?: Int, sync?: SyncMode)`,
  `mkdir(... recursive?: Bool, allow_exist?: Bool)`, `File.sync`, `File.close`,
  and `rename(... replace?: Bool)`. `rename` defaults to replacement; production
  never calls it. `create` also defaults to replacement/truncation; production
  always explicitly sets `allow_existing=false`.
- `src/fs/file.mbt:157` maps that false flag to `CreateNew`.
  `src/internal/event_loop/fs.c:962–993` maps this enum to `CREATE_NEW` in
  `CreateFileW`, with shared read/write/delete access. `open` exposes no
  no-follow option for ordinary files.
- `src/internal/event_loop/fs.c:410–424` adds
  `FILE_FLAG_OPEN_REPARSE_POINT` for a no-follow stat of the final component;
  reparse classification uses `FILE_ATTRIBUTE_REPARSE_POINT`. Parent components
  must be checked individually. Existing `path_has_link_component` does that.
  Tests create real Windows directory junctions through `fs.symlink` and verify
  both explicit and nested traversal refusal, including a link-only directory.
- `src/internal/event_loop/fs.c:1972–2000` implements Windows realpath using
  `CreateFileW` and `GetFinalPathNameByHandleW` with normalized DOS names.
  The new destination is resolved from its existing parent plus a validated
  leaf; Windows local `//?/` result spelling is converted to an ordinary DOS
  absolute path before slash joining. Input aliases use the existing discovery
  identity keys. Portable filename folding is deliberately ASCII-only.
- `src/internal/event_loop/fs.c:1274–1278` maps `File.sync()` to
  `FlushFileBuffers`. `src/fs/file.mbt:27` delegates close to the event loop;
  `src/internal/event_loop/io.mbt:73–82` shows idempotent close suppresses errors.
  Thus explicit sync errors are observable; close success is not separately
  attestable. Reopening and byte/parse validation adds a distinct check.
- `src/fs/dir.mbt:30–59` defaults to nonrecursive, non-reusing directory
  creation. `src/internal/event_loop/fs.c:1815–1822` uses
  `CreateDirectoryW(path, NULL)` on Windows. Windows ignores the Unix-style
  permission argument; directories/files inherit the parent's Windows ACL.
  The implementation requests 0700 directories and 0600 files for Unix hosts.
- `src/internal/event_loop/fs.c:1501–1546` uses
  `SetFileInformationByHandle(FileRenameInfoEx)` with flags 0 when replacement
  is false. On `ERROR_INVALID_PARAMETER`, it falls back to
  `MoveFileExW(MOVEFILE_COPY_ALLOWED | optional replacement)`. This does not
  provide a universal atomic/durable directory-transaction guarantee. The
  permitted fallback strategy is therefore exclusive per-file publication.
  A real-host test confirms no-replace directory rename refuses an existing
  directory and preserves both directories; this observation is not promoted
  into a stronger cross-system guarantee.

`moon ide doc '@fs.create'`, `moon ide doc '@fs.rename'`, and initial standard
library queries returned `Fail to load core: no metadata is available for any
backend`. Those unsuccessful queries are not API evidence; the exact cached
generated interfaces and implementation above are the source of truth.
`async/io/pkg.generated.mbti` confirmed read data conversion is `.binary()`,
not `.to_bytes()`. Installed `core/builtin/string.mbt` and `string_test.mbt`
confirm ordinary String comparison is length-first, while `lexical_compare`
is lexical; test directory inventories explicitly use the latter. Existing
input discovery keeps its original deterministic sort.

No handle-relative parent traversal or no-follow exclusive file-open primitive
is exposed at this boundary. Repeated static checks do not eliminate TOCTOU
races. The supported contract requires trusted, stable local directory trees;
concurrent hostile parent/path replacement is explicitly unsupported. Tests
do not claim race resistance. Directory fsync/crash-durable batch semantics and
private Windows ACL creation are also not claimed. These limits and recovery
instructions are in README and `docs/formats-and-limits.md`.

## TDD evidence

Before any production change, authored eight async CLI/filesystem tests using
the existing `run_cli` boundary. The file is `redact_cli_wbtest.mbt`, following
the existing CLI whitebox convention so it can access private functions; no
production API was made public merely for tests.

First `moon test cmd/main --filter 'redact*' --deny-warn` found a fixture API
mistake: abstract `async/io.Data` has `.binary()`, not `.to_bytes()`. Corrected
that from its generated interface before measuring RED. Also used the shared
invalid-XML code instead of guessing its spelling.

The next identical command exited 1, with the expected missing-command failures:

```text
redact validates CLI options without echoing values: false is not true
redact refuses empty results and missing inputs without publication: false is not true
redact rejects missing output and existing nested or aliased destinations: false is not true
redact preview has no output or staging side effects: 2 != 0
redact write validates exports and preserves original bytes: 2 != 0
redact rejects reparse ancestors on inputs and destinations: false is not true
redact mixed valid invalid batch fails closed with private diagnostics: false is not true
redact rejects derived basename collisions before staging: false is not true
Total tests: 8, passed: 0, failed: 8.
```

Implemented the command, mapping/preflight, bounded input reading, staging and
publication only after that RED run. The first implementation check identified
that `MetadataCategory` does not implement `Eq`; selected creator checks now use
pattern membership. The first executable run passed 5/8: one real failure was
missing successful output paths; two were test inventory assumptions about
String sort ordering. Added successful canonical output paths and changed only
the inventory comparison to explicit lexical order. Then the same command
exited 0: `Total tests: 8, passed: 8, failed: 0.`

Added a targeted link-only-directory regression before changing that behavior.
After correcting a fixture variable using the reserved word `unsafe`, ran:

```text
moon test cmd/main --filter 'redact link-only*' --deny-warn
redact link-only directory fails closed even with zero discovered files:
  FAILED: 0 != 2
Total tests: 1, passed: 0, failed: 1.
```

The reason was a nested-link warning with zero discovered files and hence zero
failed-file count. Redaction now escalates all discovery diagnostics to errors.
The focused command then passed 13/13, including additional coverage for
portable path aliases, case collisions, existing staging sentinels, Windows
exclusive-create/no-replace primitives, corrupt staged candidates, and quoted
diagnostic paths. Those additional primitive/helper checks are coverage tests;
they were not falsely recorded as independent pre-implementation RED cycles.

Added three further coverage tests for canonical alias deduplication and sibling
prefixes, exact per-file/collection byte budgets and all fourteen metadata
labels with a negative center. Final focused result:

```text
moon test cmd/main --filter 'redact*' --deny-warn
Total tests: 16, passed: 16, failed: 0.
```

The mixed valid/invalid test proves `files=2 ready=1 failed=1 written=0`, stable
XML diagnostic and bad filename, no source-secret echo and no destination or
stage. The corrupt-candidate test independently verifies stage validation
fails before final directory creation and removes its staging files. Existing
destination/staging sentinels and all source byte arrays remain unchanged.

## Required native temporary-directory examples

Ran the built native executable from a PowerShell script at
`_build/task13-smoke.ps1` (ignored generated test support). The script creates
a unique system-temporary root, copies all three checked-in synthetic examples,
retains each source's complete byte array via injective Base64 encoding, and
compares full bytes after preview, write and rejection. Cleanup resolves the
absolute temporary root, verifies it equals the explicitly selected root and
stays under the system temporary directory, then removes only that verified
root with native PowerShell `Remove-Item -LiteralPath`.

Command: `& ./_build/task13-smoke.ps1`, exit 0. Its exact semantic output below
uses `<TEMP>` for the generated root
`C:/Users/gunter/AppData/Local/Temp/trackshield-task13-smoke-80a7757a0e47412aae657c322da99f08`;
path separators/escaping are normalized here for readability. The audit JSON
was emitted in full during execution; its diagnostic array was empty.

```text
COMMAND: main.exe redact <TEMP>/inputs --center 0,0 --radius-m 100 --remove-metadata creator --output-dir <TEMP>/missing/preview
Preview: files=3 ready=3 failed=0 written=0
source="<TEMP>/inputs/activity-a.gpx" points_removed=1 segments_created=0 routes_removed=0 waypoints_removed=0 metadata_fields_removed=1
would_write_basename="activity-a.gpx"
source="<TEMP>/inputs/activity-b.gpx" points_removed=1 segments_created=0 routes_removed=0 waypoints_removed=0 metadata_fields_removed=1
would_write_basename="activity-b.gpx"
source="<TEMP>/inputs/activity-c.gpx" points_removed=0 segments_created=0 routes_removed=0 waypoints_removed=0 metadata_fields_removed=1
would_write_basename="activity-c.gpx"
Cleaned files and reports remain sensitive.
ASSERT: preview exit=0; no output or staging paths; originals byte-identical 3/3
COMMAND: main.exe redact <TEMP>/inputs --center 0,0 --radius-m 100 --remove-metadata creator --write --output-dir <TEMP>/exports
Write: files=3 ready=3 failed=0 written=3
source="<TEMP>/inputs/activity-a.gpx" points_removed=1 segments_created=0 routes_removed=0 waypoints_removed=0 metadata_fields_removed=1
source="<TEMP>/inputs/activity-b.gpx" points_removed=1 segments_created=0 routes_removed=0 waypoints_removed=0 metadata_fields_removed=1
source="<TEMP>/inputs/activity-c.gpx" points_removed=0 segments_created=0 routes_removed=0 waypoints_removed=0 metadata_fields_removed=1
Cleaned files and reports remain sensitive.
output="<TEMP>/exports/activity-a.gpx"
output="<TEMP>/exports/activity-b.gpx"
output="<TEMP>/exports/activity-c.gpx"
ASSERT: write exit=0; exports=3; staging remnants=0; originals byte-identical 3/3
COMMAND: main.exe audit <TEMP>/exports --format json
[JSON report: three files parsed, diagnostics=[], center=null; full JSON emitted during execution]
ASSERT: independent hardened audit/reparse exit=0
COMMAND: main.exe redact <TEMP>/inputs --center 0,0 --radius-m 100 --write --output-dir <TEMP>/exports (existing)
Write: files=3 ready=0 failed=3 written=0
Cleaned files and reports remain sensitive.
error output.exists "<TEMP>/exports": destination already exists
ASSERT: repeated destination exit=2; originals byte-identical 3/3
CLEANUP: verified temporary root removed
```

## Final verification and generated interface review

All commands run in the local checkout on this Windows host:

| Command | Exit | Exact significant output |
| --- | --- | --- |
| `moon test cmd/main --filter 'redact*' --deny-warn` | 0 | `Total tests: 16, passed: 16, failed: 0.` |
| `moon test --deny-warn` | 0 | `Total tests: 138, passed: 138, failed: 0.` |
| `moon fmt --check` | 0 | `Finished. moon: ran 54 tasks, now up to date` |
| `moon check --deny-warn` | 0 | `Finished. moon: ran 46 tasks, now up to date` |
| `moon build --target native --deny-warn` | 0 | `Finished. moon: ran 3 tasks, now up to date`; artifact `Zcxssxx/trackshield/cmd/main native .../_build/native/debug/build/cmd/main/main.exe` |
| `moon info` | 0 | `Finished. moon: ran 33 tasks, now up to date` |
| `& ./_build/task13-smoke.ps1` | 0 | Assertions and native output above |
| `git diff --check` | 0 | No whitespace errors; Git only warned that LF will be replaced by CRLF for existing tracked files |

Native linking printed the normal Windows import-library/object creation lines;
there were no compiler warnings in strict checks. `moon info` changes only
`cmd/main/pkg.generated.mbti`: opaque `PreparedOutput` and `RedactConfig` types
are listed alongside existing private CLI types. No public CLI functions,
fields, library values or library/model interfaces changed.

The task brief is intentionally untracked and excluded from the feature commit.
The complete report is included. Commit identity is explicitly set for both
author and committer to `Zcxssxx <Zcxssxx@users.noreply.github.com>`, with subject
`feat: add preview-first redaction CLI`.

## Continuation verification (2026-10-26)

After the final staging-cleanup ownership regression was added, reran the
current checkout rather than relying on the earlier session output:

| Command | Exit | Result |
| --- | --- | --- |
| `moon test cmd/main --filter 'redact*' --deny-warn` | 0 | `Total tests: 17, passed: 17, failed: 0.` |
| `moon test --deny-warn` | 0 | `Total tests: 139, passed: 139, failed: 0.` |
| `moon fmt --check` | 0 | `Finished. moon: no work to do` |
| `moon check --deny-warn` | 0 | `Finished. moon: ran 33 tasks, now up to date` |
| `moon build --target native --deny-warn` | 0 | Artifact produced at `_build/native/debug/build/cmd/main/main.exe` |
| `moon info` | 0 | Regenerated only the intended CLI type entries in `cmd/main/pkg.generated.mbti` |
| `git diff --check` | 0 | No whitespace errors; Git reports only the configured LF-to-CRLF working-copy notice |
| `& ./_build/task13-smoke.ps1` | 0 | Preview/write/reparse/repeat-destination assertions all completed; originals remained byte-identical 3/3 |

The first wrapper invocation propagated the product's expected exit code 2
from the deliberate existing-destination rejection. A second invocation
checked the PowerShell script's own success state, completed cleanup, and
exited 0. Its assertions confirm the repeated destination itself correctly
returns 2. Native compilation printed upstream dependency warning C4005 for
the `EINVAL` macro in `moonbitlang/async` against the Windows SDK; strict
MoonBit check/test/build completed without MoonBit diagnostics.

Current local toolchain evidence from `moon version --all`:
`moon 0.1.20261023`, `moonc v0.10.17+d971670cd`, and `moonrun 0.1.20261023`.

## Independent review and follow-up fix

The read-only Task 13 review found no Critical or Important issues and one
Minor issue: U+0085, U+2028 and U+2029 could split plain-text path diagnostics
in Unicode-aware log viewers. Added a regression test first and observed the
expected RED failure containing the unescaped separators. `quoted_path` now
replaces all three with `?`; the same test passed GREEN (1/1). The reviewer
re-reviewed the fix and reported the finding addressed with no new actionable
issues.

Post-fix verification:

| Command | Exit | Result |
| --- | --- | --- |
| `moon test cmd/main --filter 'redact*' --deny-warn` | 0 | `Total tests: 18, passed: 18, failed: 0.` |
| `moon test --deny-warn` | 0 | `Total tests: 140, passed: 140, failed: 0.` |
| `moon fmt --check` | 0 | `Finished. moon: no work to do` |
| `moon check --deny-warn` | 0 | `Finished. moon: ran 35 tasks, now up to date` |
| `moon build --target native --deny-warn` | 0 | Native CLI artifact built; `moon: ran 3 tasks` |
| `moon info` | 0 | `Finished. moon: ran 33 tasks, now up to date`; interface diff remains the two intended internal CLI types |
| `git diff --check` | 0 | No whitespace errors; only LF-to-CRLF working-copy notices |
| `& ./_build/task13-smoke.ps1` | 0 | Post-review rerun passed preview, write, independent audit/reparse, existing-destination rejection, and source-byte preservation assertions |

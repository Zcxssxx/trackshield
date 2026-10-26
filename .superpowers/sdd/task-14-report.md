# Task 14 report: adversarial, compatibility, and regression tests

Date: 2026-10-26 (Asia/Shanghai)

## Synthetic collection fixtures

Added two original collections under `testdata/`. `qualifying/` has three
distinct GPX files whose start points form exactly one component under the
default 500 metre radius; its three endpoints are mutually more than 1 km
apart and outside that start component. `below-threshold/` has two files with
nearby starts, below the default three-file support threshold. The README
documents that the fixtures are hand-authored deterministic synthetic values,
not tracks or personal data from real activities.

Direct native CLI evidence:

```text
moon run cmd/main -- audit testdata/qualifying
exit 0; repeated endpoint clues: location-1, 3 files, 3 tracks; diagnostics: none

moon run cmd/main -- audit testdata/below-threshold
exit 0; repeated endpoint clues: none; diagnostics: none
```

The new CLI test checks both collections, compares full JSON stdout across
repeated audits, and reverses explicit input order while requiring exit code
zero and identical stdout/stderr.

## Property and regression coverage

Added generated redaction cases around the equator, antimeridian, and north
pole. Every case asserts exact retained counts for waypoints, route points,
track points, and split track segments before iterating. It then checks the
GPX coordinate bounds and verifies every retained waypoint, route point, and
track point lies outside the explicitly supplied circle.

The pinned `moongpx@0.1.0` parser accepts GPX longitude in `[-180, 180)` and
rejects `180`; its `geo_test.mbt` explicitly covers both endpoints. The test
therefore uses `< 180` for parser-backed GPX values. TrackShield's standalone
`GeoPoint` constructor accepts `180`, but that does not make it valid in this
parser's GPX input domain.

The broader existing suite already includes dateline/high-latitude distance
and redaction, inclusive exact-radius behavior, identical coordinates, empty
and multi-segment tracks, GPX 1.0/1.1, transitive wide components, duplicate
file support, default privacy and coordinate opt-in, preview purity, output
collisions, segment splitting, selected metadata and preserved extensions,
malformed XML/namespaces/DOCTYPE/external-entity guards, bounded input sizes,
and unreadable/closed-file I/O paths. The CLI-specific test for ACL-denied
regular files is not run on this Windows host; no ACL mutation is performed.

TDD evidence: the new end-to-end collection test first failed because its
testdata paths did not yet exist; after adding the authored fixtures it passed
1/1. The first generated coordinate set used GPX longitude `180`, and the
strict test exposed the parser rejection. Inspection of the exact pinned
dependency source and tests identified the half-open GPX interval; replacing
that invalid fixture value with `-179.999` made the property test pass 1/1.
No production code changed in Task 14.

## Review

Independent review confirmed that the fixture thresholds and full JSON order
comparisons are correct. It asked for non-vacuous retained point assertions
and reverse-input exit/stderr assertions; those were added. It also suggested
testing `+180`; this was declined for parser-backed GPX output because the
format parser rejects that longitude, despite the standalone model accepting
it. The reviewer re-reviewed and found no remaining actionable issues.

## Verification

| Command | Exit | Result |
| --- | --- | --- |
| `moon test cmd/main --filter 'synthetic collections exercise the three-file audit threshold and stable output' --deny-warn` | 0 | 1/1 passed |
| `moon test redact --filter 'redacted output coordinates stay in range and outside the explicit zone' --deny-warn` | 0 | 1/1 passed |
| `moon test --deny-warn` | 0 | 142/142 passed |
| `moon fmt --check` | 0 | `Finished. moon: ran 54 tasks, now up to date` |
| `moon check --deny-warn` | 0 | `Finished. moon: ran 35 tasks, now up to date` |
| `moon build --target native --deny-warn` | 0 | Native CLI artifact built; `moon: ran 65 tasks` |
| `moon info` | 0 | `Finished. moon: ran 33 tasks, now up to date`; no generated interface changes |
| `git diff --check` | 0 | No whitespace errors; Git only emitted LF-to-CRLF notices |

The first `moon fmt --check` after adding tests detected formatting deltas; its
Windows diff invocation could not render the non-ASCII workspace path. Ran
`moon fmt`, then a fresh `moon fmt --check` passed. Native C compilation
printed upstream `moonbitlang/async` warning C4005 for `EINVAL` against the
Windows SDK; MoonBit strict check and tests had no diagnostics.

## Local commit

Feature/test commit: `493df82 test: cover GPX privacy and redaction edge cases`.
Author and committer are `Zcxssxx <Zcxssxx@users.noreply.github.com>`. No
remote, GitHub identity, GitHub API, or hosted CI was accessed.

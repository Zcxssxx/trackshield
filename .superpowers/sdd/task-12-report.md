# Task 12 report: safe in-memory GPX transformation

Base: `20bc60b` on `codex/trackshield-development`.

Implemented `redact.redact_gpx` and the public `api.redact_gpx` facade. The
operation accepts only the caller's explicit circle, options, and limits. It
does not consult audits, access the filesystem, write outputs, or use a network.
Caller bytes/options are unchanged. `RedactedFile` is now constructed by the
real successful transformation path; no diagnostic was suppressed and no dummy
construction was added.

## Preservation strategy and exact dependency evidence

Inspected the locally pinned sources before implementation:

- `2973181701/moongpx@0.1.0`: `model.mbt`, `serialize.mbt`, `parse.mbt`,
  `parse10.mbt`, package configuration and tests. Models have read-only external
  fields. The GPX serializer regenerates a GPX 1.1 root with only the standard
  namespace/version/creator attributes, cannot retain unknown optional fields or
  inherited extension namespace declarations, and GPX 1.0 parsing migrates into
  a 1.1 model (including synthetic course/speed extensions).
- `Milky2018/xml@0.4.1`: generated interface, event/attribute/source-span types,
  reader source and `source_span_test.mbt`. Event spans are UTF-16 offsets into
  the original String, matching String slicing. Attribute value spans omit
  their quote delimiters. A direct dependency on this exact already-cached
  version is now declared; no dependency was fetched or changed upstream.

Using the generic GPX serializer would silently discard unselected information.
The implementation instead uses the pinned XML reader's source ranges to splice
only selected elements, removed points/parents, creator value, and new segment
wrappers. Untouched source slices retain numeric spellings, whitespace, CRLF,
BOM, comments, CDATA, entity spellings, unknown fields, attributes, and namespace
bindings. All XML parsing follows successful existing hardened GPX preflight;
DOCTYPE/entity policy, resource bounds, supported versions/namespaces and point
ranges therefore remain shared. `gpx/adapter.mbt` required no change: both source
and candidate call its existing `parse_input` directly.

New `redact/source.mbt` owns source-range traversal, `redact/metadata.mbt` owns
metadata path/category selection, and `redact/transform.mbt` owns the public
operation and candidate checks. Existing Task 11 preview/counting code remains
unchanged.

## Behavior

- Remove every track/route/standalone point at distance <= the explicit radius.
  Emit a separate track segment for each retained run, including leading,
  middle, consecutive and trailing removed runs. Original segment boundaries
  are never joined. Routes retain only outside points; standalone waypoints are
  filtered. Empty tracks/routes are omitted and their preview diagnostics are
  included. No `RedactedFile` is returned if all point content would be empty.
- Preserve unselected supported fields and opaque extension/unknown subtrees.
  Remove only selected creator/name/description/author/link/point timestamp/
  extension categories at their owning paths. Replace a selected creator with
  `TrackShield`, since GPX requires that attribute; do not remove its schema
  requirement. Metadata time, copyright, bounds, keywords, comments, sources,
  precision fields, and all other unselected values remain intact.
- Duplicate category choices have boolean membership, matching Task 11. Fields
  lost with removed parents are excluded from selected-field preview counts.
- Preserve an originally empty segment's unselected fields when another segment
  retains the track. Empty segments with no remaining fields can be omitted.
- Do not invent ownership for unselected segment-level extensions, unknown
  child fields, or non-namespace attributes when splitting. Return
  `gpx.lossless_redaction_unsupported` and no candidate in these ambiguous cases.
  Selected segment extensions can be removed before splitting safely.
- Reparse each candidate through the same hardened adapter before returning it.
  Validate normalized supported version, total point-removal counts,
  standalone waypoint/route-removal counts, generated segment count, remaining
  circle membership, and selected metadata removal. A candidate parse/limit or
  invariant failure returns the same stable lossless diagnostic, without raw
  parser/source details.

## TDD RED/GREEN evidence

1. Authored the initial nine transformation tests before implementing the
   operation. Added only a temporary typed placeholder returning
   `redact.not_implemented`, with no transformation logic.
2. The first `moon test redact` exposed fixture compilation issues: String
   replacement requires labeled `old`/`new` arguments, and Option `is_empty` is
   deprecated. Corrected these before measuring RED.
3. `moon test redact` then exited 1 at
   `transform splits leading middle trailing and consecutive removed runs`:
   `Result::unwrap()` on the placeholder Err, native exit `0xc0000409`. The
   process stops on that deliberate panic, so additional explicit RED runs were
   made:

   | Command | Actual RED result |
   | --- | --- |
   | `moon test redact --filter 'transform selected*'` | exit 1; placeholder Err unwrap in selected-category test |
   | `moon test redact --filter 'transform refuses all*'` | exit 1; 0/1 passed; `redact.not_implemented` != `redact.empty_result` |
   | `moon test redact --filter 'transform source spans*'` | exit 1; placeholder Err unwrap in BOM/CRLF/supplementary/unknown-field test |

4. Implemented source-span editing, metadata category selection, filtering/run
   splitting and candidate validation. An initial import-resolution failure
   confirmed XML must be declared directly; declared the same cached 0.4.1.
   Compiler feedback corrected an unavailable Array search method, invalid
   Result postfix propagation, and deprecated StringView ownership conversion.
   `moon test redact` then passed 22/22, with no warnings.
5. Added an empty-segment preservation regression before fixing the behavior,
   plus tests exercising every supported point field/opaque extension payload
   and both input/candidate size guards. The command
   `moon test redact --filter 'transform preserves unselected*'` exited 1,
   0/1 passed: actual parsed output had discarded the originally empty segment's
   unselected extension, while expected retained it. Added retention of those
   fields. `moon test redact --deny-warn` then passed 25/25.
6. Formatted and reran targeted/full strict checks. Final tests include 12 new
   transformation tests plus all 13 existing redaction-preview tests.

Test evidence covers leading/middle/trailing/consecutive/all-point removals,
multiple original segments, inclusive boundary/just-outside points, route and
waypoint filtering, omitted-parent diagnostics, metadata-only and otherwise
empty outputs, all selected categories individually (including duplicate
choices), preserved unselected fields, full supported point fields, extension
payload opacity, inherited namespace bindings, unknown optional fields,
GPX 1.0 version/course/speed preservation, stable lossless refusal, BOM/CRLF and
supplementary-plane source offsets, caller bytes, deterministic repeated calls,
safe malformed/DOCTYPE/range errors, and source/candidate limits. Every success
test's helper reparses returned bytes independently through the hardened
adapter; the production path also reparses before returning.

## Final verification

All work was local. No GitHub, remote, authentication or network actions ran.

| Actual command | Final result |
| --- | --- |
| `moon fmt` | exit 0 |
| `moon fmt --check` (separate invocation) | exit 0 |
| `moon test redact --deny-warn` | exit 0; 25 passed, 0 failed; no warnings |
| `moon test --deny-warn` | exit 0; 114 passed, 0 failed; no warnings |
| `moon check --deny-warn` | exit 0; no diagnostics |
| `moon build --deny-warn` | exit 0; native executable generated; later incremental invocation also exits 0 |
| `moon info` | exit 0; generated interfaces reviewed |
| `git diff --check` | exit 0; no whitespace errors; Git emits LF-to-CRLF notices |

The first native build compiled upstream async C sources and emitted an existing
`fs.c(32): warning C4005: EINVAL macro redefinition`, referencing the Windows SDK
`errno.h`. This is distinct from MoonBit warning-denial results. It was not
suppressed or patched. The full build exited 0 and incremental rebuild is clean.

`moon ide doc 'Array::find*'` and `moon ide doc 'StringView::to_owned'` could not
load local core metadata in that discovery context; exact XML APIs were verified
from pinned generated interfaces/source, and StringView ownership was confirmed
by compiler diagnostics and successful strict compilation.

Generated `moon info` changes are intentional and limited to:
`api.redact_gpx`, `redact.redact_gpx`, and the model constructor
`make_redacted_file(Bytes, RedactionPreview)`. No source-tree/XML dependency type
is exposed by the facade.

## Remaining limitations

- Ambiguous unselected segment metadata on a split fails closed rather than
  assigning or duplicating it. This is an explicit supported refusal path.
- GPX 1.0 source is preserved rather than upgraded. Selecting Extensions while
  its parser synthesizes course/speed as extension data can fail the metadata
  invariant and return the stable lossless diagnostic; no misleading successful
  bytes are returned.
- Transformation makes multiple bounded parse passes and has not been
  benchmarked at the maximum input limits. The existing parser acceptance rules
  and spherical distance model remain the source of truth.
- Output files/CLI redaction, audit-derived zones, publication and network work
  are outside this task. This operation only returns in-memory bytes.

## Review fix wave: opaque segment ownership and exact empty-segment counts

The review of `5bcb0c7` reported two Important findings and the already recorded
Minor upstream C4005 warning. Both root causes were independently verified before
editing production code:

1. `source_tree` kept only Start/Empty/End events. Its empty-segment retention and
   split-ambiguity checks only examined child elements and non-namespace
   attributes. Direct text/CDATA in an originally empty segment was therefore
   silently discarded, while direct text/CDATA on a split segment could be
   assigned to an output run without a safe ownership rule.
2. Preview counted segment Extensions only when the segment had retained point
   runs. An originally empty segment with unselected custom content could remain
   in the output after removing its selected extension, but that actual removal
   was absent from both public preview and `RedactedFile.preview`.

The source tree now records direct meaningful Text/CDATA and direct comments or
processing instructions as opaque content of the current element. Only the four
ordinary XML formatting whitespace characters (space, tab, CR, LF) are excluded
from meaningful text. Nested extension payload content belongs to its own node,
so it does not become direct opaque content of its segment. The existing source
slices preserve that content verbatim where ownership is unambiguous.

One shared `segment_has_unselected_content` predicate now governs ambiguous
split refusal and originally empty segment retention. A second shared predicate
`retain_originally_empty_segment` is used by transformation and preview's
source-aware count adjustment. The adjustment counts selected extension
containers removed from retained originally empty segments, only when their
enclosing track retains point content. Segments emptied by clipping and omitted
tracks continue to contribute no selected metadata removals. If the additional
guarded source analysis cannot derive counts, preview returns a stable lossless
diagnostic with safe zero counts instead of claiming an exact result.

### Fix-wave RED/GREEN evidence

Seven focused tests were authored before the production fix. Each failure was
run independently to avoid a preceding failure hiding the next case:

| Exact RED/control command | Exit and actual diagnostic/output |
| --- | --- |
| `moon test redact --filter 'review empty segment retains direct CDATA'` | exit 1; byte-equality assertion failed because the direct CDATA segment disappeared; `Total tests: 1, passed: 0, failed: 1.` |
| `moon test redact --filter 'review empty segment retains direct text'` | exit 1; byte-equality assertion failed because the direct text segment disappeared; `Total tests: 1, passed: 0, failed: 1.` |
| `moon test redact --filter 'review split segment refuses direct CDATA'` | exit 1; `FAILED: split CDATA ownership is ambiguous`; `Total tests: 1, passed: 0, failed: 1.` |
| `moon test redact --filter 'review split segment refuses direct text'` | exit 1; `FAILED: split text ownership is ambiguous`; `Total tests: 1, passed: 0, failed: 1.` |
| `moon test redact --filter 'review retained empty segment counts*'` | exit 1; `FAILED: 0 != 1` (terminal renders those values in backticks); `Total tests: 1, passed: 0, failed: 1.` |
| `moon test redact --filter 'review omitted*'` | exit 0 before the fix; `Total tests: 1, passed: 1, failed: 0.` |
| `moon test redact --filter 'review ordinary*'` | exit 0 before the fix; `Total tests: 1, passed: 1, failed: 0.` |

The last two were baseline controls, not falsely reported RED failures. They
assert that metadata on a clipped-away segment, an omitted enclosing track, or a
segment containing only selected Extensions is excluded from removal counts,
and that ordinary CR/LF/tab/space formatting does not block splitting.

After the implementation, the exact command
`moon test redact --filter 'review*' --deny-warn` exited 0 with:

```text
Total tests: 7, passed: 7, failed: 0.
```

The selected-extension count regression exercises four retained-empty-segment
owners: custom child, custom attribute, direct CDATA, and direct text. In each
case it independently checks public preview and returned preview equal 1,
duplicate selection counts once, output bytes equal the exact source with only
the selected extension removed, and the hardened parser sees both segments.
Direct-content preservation checks include supplementary-plane text and XML
entities. Ambiguous split cases require the exact
`gpx.lossless_redaction_unsupported` diagnostic and no returned candidate.

A new filesystem-observation integration test covers both preview and
transformation for the selected-Extensions/opaque-empty-segment path, asserts
exact counts, unchanged input bytes, hardened reparsing, unchanged directory
contents, and no creation of the supplied nonexistent source path or its parent.
The first purity-test invocation exposed the fixture's wrong facade enum spelling
(`Value Extensions not found in package api`); using the project's established
`@api.MetadataCategory::Extensions` spelling corrected that compilation issue.
The corrected test passes without changing production behavior.

### Fix-wave final verification

Each command below was invoked separately after formatting; all exited 0.
The quoted test summaries are the exact terminal outputs:

| Command | Exact summary/output |
| --- | --- |
| `moon fmt` | `Finished. moon: ran 4 tasks, now up to date` |
| `moon test redact --deny-warn` | `Total tests: 32, passed: 32, failed: 0.` |
| `moon test tests/preview_purity --deny-warn` | `Total tests: 2, passed: 2, failed: 0.` |
| `moon test --deny-warn` | `Total tests: 122, passed: 122, failed: 0.` |
| `moon check --deny-warn` | `Finished. moon: ran 35 tasks, now up to date` |
| `moon fmt --check` | `Finished. moon: ran 51 tasks, now up to date` |
| `moon build --deny-warn` | `Finished. moon: ran 5 tasks, now up to date`; native executable generated |
| `moon info` | `Finished. moon: ran 33 tasks, now up to date` |
| `git diff --check` | no whitespace errors; existing Git LF-to-CRLF notices only |

Generated interfaces were inspected and are unchanged by this fix wave. The
incremental native build emitted no C warning in this run; the earlier upstream
`EINVAL` macro redefinition remains accurately documented above and was neither
suppressed nor modified. No GitHub, remote, authentication or network actions
ran. No new unresolved correctness concern was found; the earlier explicit
lossless refusal and bounded multiple-parse limitations remain applicable.

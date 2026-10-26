# Formats and limits

TrackShield accepts GPX 1.0 and 1.1 in the supported Topografix namespaces.
The shared input guard rejects malformed XML, DTD declarations, invalid UTF-8,
unsupported encodings/namespaces, out-of-range point coordinates and resource
limit violations. Diagnostics use stable codes and messages without copying
parser details, coordinates, timestamps or metadata values. Reports contain
paths, which can themselves be sensitive; control characters in redaction
report paths are quoted or replaced.

## Redaction command

```text
trackshield redact <path>... --center LAT,LON --radius-m N
  [--remove-metadata CATEGORY,...] [--write --output-dir DIR]
```

The center must be finite, with latitude in [-90, 90] and longitude in
[-180, 180]. Radius must be positive and at most 20,037,508 metres. The circle
is supplied by the user and is never inferred from audit findings. Points at
distance <= radius are removed from tracks, routes and standalone waypoints.
Retained track runs become separate segments, so removed gaps are not joined.
Empty tracks/routes are omitted. A file with no remaining point content is
unpublishable (`redact.empty_result`). Preview also diagnoses unpublishable
transformations; a successful preview is a plan for a publishable batch.

Supported metadata labels are `creator`, `metadata_name`,
`metadata_description`, `author_name`, `author_email`, `link`, `track_name`,
`track_description`, `route_name`, `route_description`, `waypoint_name`,
`waypoint_description`, `point_timestamp`, and `extensions`. Unknown or empty
labels are usage errors; duplicate choices have membership semantics. Selected
creator is replaced with `TrackShield` because GPX requires that attribute.
Unselected source slices, spelling, whitespace, comments and opaque extensions
are retained by the shared `api.redact_gpx` transformation. If splitting would
give ambiguous ownership to unselected segment attributes/children, the
transformation refuses with `gpx.lossless_redaction_unsupported`.

## Discovery, mapping and budgets

The command reuses audit's recursive deterministic discovery, lowercase `.gpx`
extension selection and canonical-path deduplication. Explicit other extensions
are errors; unrelated extensions inside directories are ignored. Redaction
rejects every discovery diagnostic, including an otherwise skippable nested
link, instead of publishing a partial collection. Existing empty directories
are valid empty collections. Input files are opened read-only.

Redaction uses the default shared limits: 32 MiB per input, 250,000 points per
file, 500 candidate files and 256 MiB of accepted source bytes. The shared XML
limits also apply (depth 128, 500,000 elements). Redaction has no CLI limit
overrides. Reads are bounded to the remaining budget plus one byte to detect
growth. The transformation and staged/final reparse independently enforce the
same per-file limits. Candidates are retained in memory, so peak memory exceeds
the source budget due to XML structures, transformed bytes and temporary copies.

Output is a flat directory: each discovered source maps to its unchanged
basename in the new output directory. The complete map is checked before any
staging creation. ASCII case-insensitive duplicate basenames are rejected even
on a case-sensitive host. To avoid Windows devices, alternate streams and
unverified Unicode case equivalence, exported basenames and the destination
leaf name are limited to 1–180 ASCII letters/digits/dots/underscores/hyphens,
excluding `.`/`..`, trailing dots and reserved device stems (`CON`, `PRN`, `AUX`,
`NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`, regardless of extension or case). This means
a source basename containing spaces or non-ASCII characters must be renamed
by the user before exporting. Unicode ancestor directories are supported.

Only ordinary local paths are supported. UNC/device paths, drive-relative
paths, alternate streams, wildcard/control characters, trailing spaces or
ambiguous trailing dots in components are rejected. `.`/`..` aliases in ancestor
components are resolved through the filesystem. Existing parents are checked
component by component with `kind(follow_symlink=false)` before canonicalizing
with `realpath`. The resolved destination must not equal, contain, or be within
an input directory, or contain any input file. Containment uses a separator
boundary, so `input-other` is distinct from `input`.

## Publication and actual filesystem guarantees

Preview never invokes staging or destination creation. Even if an output path
is supplied, preview only prints derived basenames; it does not validate that
destination. Successful write output includes canonical absolute published
paths. `files` counts discovered candidate files, `ready` counts successful
in-memory transformations, `failed` is discovered minus ready, and `written`
counts files whose final write, flush and validation completed. Early discovery
or destination errors can therefore report no ready files. Diagnostics identify
problems that cannot be represented by those file counts. The per-file preview
also gives removed point/route/waypoint/metadata counts and resulting segments.

Writes require both `--write` and `--output-dir`. The parent must exist and the
destination must not exist. Canonical overlap checks and the complete basename
collision check run before creating `DIR.trackshield-stage`, a new sibling
directory. A pre-existing staging path causes an error and is left untouched.
Every staging file is created with `allow_existing=false`, written, explicitly
synced and closed. Each file is reopened, checked byte-for-byte against the
candidate, parsed through the hardened adapter, and checked for remaining
circle/selected metadata content. Every staged item must validate before the
final directory is created.

The locally pinned `moonbitlang/async@0.22.5` Windows implementation maps
exclusive creation to `CreateFileW(..., CREATE_NEW)`, no-follow kind checks to
`FILE_FLAG_OPEN_REPARSE_POINT` on the final component, canonicalization to
`GetFinalPathNameByHandleW`, syncing to `FlushFileBuffers`, and directory
creation to `CreateDirectoryW`. `File.close()` is idempotent and suppresses
close errors internally; explicit sync failures remain observable. Its rename
uses `FileRenameInfoEx` and falls back to `MoveFileExW(MOVEFILE_COPY_ALLOWED)`
on older systems. No universal atomic/durable batch rename guarantee is assumed.

Final publication therefore uses a newly created directory and exclusive
per-file creation, followed by sync/close and an independent final-byte/GPX
validation before counting each file as written. Existing final files and
directories are never adopted. An I/O error can leave previously completed
files and an unvalidated partial current file, which is excluded from `written`.
`output.partial_write` returns exit 2, reports completed paths/counts and names
the affected directory. TrackShield does not
delete the final directory on failure; inspect and remove it manually before
retrying. It attempts to remove its known staging files and the now-empty
staging directory, never recursively deleting an output tree. Staging cleanup
ownership is registered only after exclusive creation succeeds, before any
write or sync can fail. Cleanup failure
returns `output.staging_cleanup_failed` with the sensitive staging path.
Process interruption or power loss can also leave staging/output remnants.
There is no crash-durable transaction or directory fsync guarantee.

These are path-based APIs: neither no-follow parent handles nor handle-relative
exclusive opens are exposed here. Static links/reparse points are rejected, but
checks and subsequent operations are not race-safe against concurrent path
replacement. Run only on local filesystems with trusted, stable inputs and
output parents; concurrent hostile writers are outside the supported contract.
Tests exercise real Windows exclusive-create and no-replace directory-rename
behavior and junction rejection; they do not prove race safety.

Unix-style directory/file permissions requested are 0700/0600. On Windows the
dependency ignores those permission arguments and inherits the parent's ACL.
Choose a parent with appropriate Windows access controls before exporting.
Cleaned files and reports remain sensitive, including retained metadata and
route points outside the explicit circle.

# TrackShield

TrackShield is an offline GPX collection auditor and redactor written primarily in MoonBit.
It looks for repeated start and end locations across distinct files and reports
metadata exposure categories without copying their raw values into findings.
Audit is read-only. A repeated endpoint is a privacy clue, not proof that a
location is a home or that a collection is anonymous.

## Build and test

```sh
moon check
moon test
moon build --target native
moon run cmd/main -- --help
```

## Audit a collection

The checked-in collection contains three authored, synthetic GPX files whose
track endpoints are intentionally close to one another. It contains no real
route or personal data.

```sh
moon run cmd/main -- audit examples/repeated-endpoints
moon run cmd/main -- audit examples/repeated-endpoints --format json
moon run cmd/main -- audit examples/repeated-endpoints --radius-m 250 --min-files 2
```

The command accepts one or more `.gpx` files or directories. Directories are
walked recursively in sorted path order. Other file extensions inside a
directory are ignored; an explicitly named non-GPX file is an error. File and
directory aliases that resolve to the same canonical path are processed once.
Static symbolic links and filesystem reparse points in any path component are
not followed. A skipped link inside a directory is reported as a warning. The default report hides cluster
centers; `--show-coordinates` is an explicit opt-in that may disclose sensitive
locations.

Resource defaults are 32 MiB per file, 250,000 points per file, 500 candidate
files, and 256 MiB total input. Override them with `--max-file-bytes`,
`--max-points`, `--max-files`, and `--max-total-bytes`. Invalid or unreadable
inputs produce a partial report for the inputs that could be analyzed.

Reports go to stdout. Usage errors and diagnostic summaries go to stderr.
Exit codes are 0 when the audit completes (warnings may be present), 1 when one
or more inputs could not be analyzed, and 2 for invalid command-line usage.
Reports include source paths, and reports or cleaned exports should be handled
as potentially sensitive data.

## Current scope

TrackShield currently audits GPX 1.0 and 1.1 exports. Unsupported namespaces,
malformed XML, DTD declarations, oversized inputs, and configured resource
limit violations are diagnosed without echoing source content. The library
also exposes deterministic text and JSON report renderers. Audit results are
never used to infer a redaction zone.

## Preview and write cleaned copies

Supply an explicit circle; the default command only previews changes and never
creates a file, directory, or staging path. `--output-dir` may be supplied during
preview, but destination validation and creation happen only with `--write`.

```sh
moon run cmd/main -- redact examples/repeated-endpoints --center 0,0 --radius-m 100
moon run cmd/main -- redact examples/repeated-endpoints --center 0,0 --radius-m 100 --remove-metadata creator,author_email
moon run cmd/main -- redact examples/repeated-endpoints --center 0,0 --radius-m 100 --write --output-dir cleaned
```

`--write` explicitly confirms writing. The output directory must be new, its
parent must already exist, and it cannot overlap any input. Inputs are processed
in the same deterministic order as audit. Outputs use a flat mapping:
`input/path/activity.gpx` becomes `cleaned/activity.gpx`. Duplicate basenames,
including ASCII case variants, reject the entire batch before staging. Export
basenames and the new directory's leaf name must use ASCII letters, digits,
`.`, `_`, or `-`, at most 180 characters, without reserved Windows device names
or trailing dots. Directory paths may contain Unicode. UNC, device paths,
alternate streams and ambiguous Windows path spellings are rejected.

Any unreadable, invalid, unsupported, empty-result, or untransformable input
prevents the batch from being written. Links and reparse points at any path
component also reject the batch. All outputs are transformed, written to a new
staging sibling, flushed, closed, reopened and parsed before final files are
created exclusively. Existing paths are never intentionally reused or replaced.
Original files are opened only for reading. Summaries give file/change counts,
published paths and stable diagnostics without source metadata or coordinates.
Redaction exits 0 for a successful preview/write and 2 for an invalid command,
input, destination or I/O failure.

Use trusted, stable directory trees. The pinned filesystem APIs do not prevent
another process from replacing a parent between a check and a path operation.
The Windows rename implementation has a copy-enabled compatibility fallback,
so publication uses exclusive per-file creation rather than claiming an atomic
batch rename. An I/O failure during publication can leave partial sensitive
files in the new output directory; exit 2 reports that condition. `written`
counts only successfully revalidated files; a partial current file can also
remain unvalidated. Inspect and
remove that directory manually before retrying. Staging cleanup is best effort
and failures name the staging path. On Windows, directories and files inherit
the parent's ACL; Unix permission arguments do not set a private Windows ACL.
Cleaned files and reports remain sensitive. See
[formats and limits](docs/formats-and-limits.md) for the precise contract.

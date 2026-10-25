# TrackShield

TrackShield is an offline GPX collection auditor written primarily in MoonBit.
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
also exposes deterministic text and JSON report renderers. Explicit-zone
redaction is planned separately; audit results are never used to infer a
redaction zone.

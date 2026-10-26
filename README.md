# TrackShield

TrackShield is an offline GPX collection auditor and explicit-zone redactor,
implemented primarily in MoonBit. It helps an athlete, hiker, cyclist, or
community moderator inspect GPX files before sharing them. Audit results show
repeat-location evidence and metadata categories; they do not identify a home,
identify a person, or certify anonymity.

TrackShield reads local files only. The audit command never changes them. The
redaction command previews by default and writes cleaned copies only after an
explicit `--write` and into a new output directory. The library API is also
available for MoonBit callers; see [package and library notes](README.mbt.md).

## Install and verify

Install a stable MoonBit toolchain using the [official installation guide](https://www.moonbitlang.com/download/),
then run these commands from the repository root. Moon resolves the pinned
Mooncakes dependencies declared in `moon.mod`.

```sh
moon version --all
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon build --target native --deny-warn
moon run cmd/main -- --help
```

The supported user-facing executable in this release is the native CLI.

## Audit a collection

The checked-in `examples/repeated-endpoints/` collection has three original,
synthetic GPX files. Their start points form one cluster under the default
500-metre radius and three-distinct-file threshold; their end points are
deliberately separated. No recorded activity or personal route is included.

```sh
moon run cmd/main -- audit examples/repeated-endpoints
moon run cmd/main -- audit examples/repeated-endpoints --format json
moon run cmd/main -- audit examples/repeated-endpoints --radius-m 250 --min-files 2
```

Audit accepts one or more `.gpx` files or directories. Directories are walked
recursively in sorted path order and select lowercase `.gpx` files. Other
extensions within a directory are ignored; an explicitly named non-GPX file is
an error. Canonical path aliases are processed once. Static symbolic links and filesystem reparse points are
not followed. A skipped link inside a directory is reported as a warning.

The default report hides cluster centers. `--show-coordinates` is an explicit
opt-in and can reveal a sensitive location. Defaults are 32 MiB per file,
250,000 points per file, 500 candidate files, and 256 MiB total input. Use
`--max-file-bytes`, `--max-points`, `--max-files`, and `--max-total-bytes` to
set lower or higher values within implementation limits. Invalid or unreadable
inputs produce a partial report for inputs that could be analyzed.

Reports go to stdout. Usage errors and diagnostic summaries go to stderr. Exit
status is 0 when analysis completes (including a report with warnings), 1 when
one or more inputs could not be analyzed, and 2 for invalid CLI usage.

## Preview and write cleaned copies

Redaction always uses a circle supplied by the user. An audit finding never
chooses the center or radius. The commands below preview a 100-metre circle
around `0,0`, then explicitly preview removal of two metadata categories, and
finally write cleaned copies into a new `cleaned` directory.

```sh
moon run cmd/main -- redact examples/repeated-endpoints --center 0,0 --radius-m 100
moon run cmd/main -- redact examples/repeated-endpoints --center 0,0 --radius-m 100 --remove-metadata creator,author_email
moon run cmd/main -- redact examples/repeated-endpoints --center 0,0 --radius-m 100 --remove-metadata creator,author_email --write --output-dir cleaned
```

Preview does not create files or validate/create an optional output directory.
Writing requires both `--write` and `--output-dir`. The output directory must
not exist, its parent must already exist, and it must not overlap any input.
The flat output mapping uses source basenames; duplicate names, including
ASCII case variants, reject the batch. Export and destination leaf names are
restricted to safe ASCII characters and Windows device-name rules.

The `--remove-metadata` categories are `creator`, `metadata_name`,
`metadata_description`, `author_name`, `author_email`, `link`, `track_name`,
`track_description`, `route_name`, `route_description`, `waypoint_name`,
`waypoint_description`, `point_timestamp`, and `extensions`. Values are
removed only when the chosen category is present. The required GPX `creator`
attribute is replaced with `TrackShield` only when `creator` is selected. GPX points inside the circle are
removed; separated retained track runs remain separate segments. Empty routes
or tracks are omitted, and a file with no remaining point content is not
written.

Redaction exits 0 for a completed preview or write and 2 for invalid command,
input, destination, or I/O errors. All inputs must be transformable before
staging starts. Each staged and final file is reopened and validated. An I/O
failure during publication may leave a
partial output directory, which is reported; inspect and remove it manually
before retrying. Static links/reparse points are rejected, but the filesystem
API cannot prevent a concurrent process replacing a checked path. Use trusted,
stable local input and output directories. On Windows, output inherits its
parent directory ACL. See [formats and limits](docs/formats-and-limits.md) for
the complete write contract.

## Supported format and privacy limits

The first release supports GPX 1.0 and 1.1 in the documented Topografix
namespaces. Malformed XML, DTD declarations, invalid encodings, unsupported
namespaces, prefixed GPX core elements, and resource-limit violations are
diagnosed without echoing source content. Opaque extension data are detected;
redaction preserves them when ownership is clear and refuses an ambiguous
split rather than silently assigning or dropping content.

Repeated endpoints and metadata findings are clues for a person's review.
TrackShield does not infer a home, workplace, or identity and does not prove a
collection anonymous. Reports contain source paths, and cleaned GPX files keep
all content outside the requested circle and selected metadata categories.
Treat paths, reports, and cleaned exports as potentially sensitive. Read the
[privacy model](docs/privacy-model.md) before using the redaction output.

## Project and sources

- [Development guide](docs/development.md)
- [Synthetic example collection](examples/README.md)
- [Third-party notices and dependency provenance](THIRD_PARTY_NOTICES.md)
- [Changelog](CHANGELOG.md)
- [Apache-2.0 license](LICENSE)

All checked-in GPX examples and fixtures are original, authored synthetic data.
TrackShield does not copy upstream implementation code or upstream test
fixtures. Dependency versions, source repositories, license identifiers, and
redistribution notes are in `THIRD_PARTY_NOTICES.md`.

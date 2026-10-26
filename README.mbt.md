# TrackShield MoonBit API

The public library surface lives in the `Zcxssxx/trackshield/api` package.
Applications provide GPX bytes and a source label; the library does not open
paths, contact a network, or write output files. The source label is retained
for local report attribution and should be treated as potentially sensitive.

## Main operations

- `GpxInput::new(path, bytes)` associates caller-provided bytes with a label.
- `default_input_limits()` returns the bounded parsing defaults.
- `inspect_gpx(input, limits)` validates and extracts per-file facts.
- `default_audit_options()` selects a 500 m radius, three distinct files, and
  hides coordinates.
- `audit_collection(inspections, options)` returns repeated endpoint clues and
  metadata-category findings.
- `render_text(report)` and `render_json(report)` provide stable renderings.
- `make_geo_point` and `make_redaction_options` validate an explicitly supplied
  circle; `preview_redaction` counts proposed changes, and `redact_gpx` returns
  transformed bytes only after revalidation.

An application can compose the audit operations as follows. `file_bytes` is
supplied by the application; no filesystem operation is hidden in this API.

```moonbit nocheck
///|
let input = @api.GpxInput::new("activity.gpx", file_bytes)

///|
let limits = @api.default_input_limits()

///|
let inspection = @api.inspect_gpx(input, limits)

///|
let report = @api.audit_collection([inspection], @api.default_audit_options())

///|
let rendered = @api.render_text(report)
```

The example shows the API composition; an application still needs to load
`file_bytes` and provide enough distinct files for a default repeated-location
finding. See [privacy model](docs/privacy-model.md) and [formats and limits](docs/formats-and-limits.md)
for input handling and disclosure details. A runnable filesystem workflow is
available through the native CLI described in [README.md](README.md).

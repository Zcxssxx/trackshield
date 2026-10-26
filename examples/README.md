# Synthetic GPX collection

`repeated-endpoints/` contains three original, hand-authored GPX files for CLI
demonstrations. Each file has a start point near `(0, 0)`. Under the default
500-metre radius, these three starts form one repeated-location component
supported by three distinct files. The three end points are over one kilometre
apart, so they do not form another component at the default radius.

The coordinates are small deterministic test values, not recorded tracks,
personal data, or copied map geometry. Each file is intentionally minimal and
exists to make the default audit result reproducible.

From the repository root:

```sh
moon run cmd/main -- audit examples/repeated-endpoints
moon run cmd/main -- audit examples/repeated-endpoints --format json
```

The default text and JSON reports contain one supported endpoint component.
Coordinates remain hidden unless the caller explicitly enables
`--show-coordinates`. See the root [README](../README.md) for redaction
examples and [testdata provenance](../testdata/README.md) for integration-test
collections, including a below-threshold control.

# Privacy model

TrackShield audits and previews GPX content supplied in memory. Audit findings
are clues for a person's review; they never select or infer a redaction zone.

`preview_redaction(input, options, limits)` requires a validated, explicitly
user-supplied latitude/longitude center and positive radius in metres. It takes
no audit report, cluster ID, output path, or filesystem handle. Inclusion uses
the existing mean-Earth-radius great-circle distance and includes the radius
boundary, including across the antimeridian and near the poles.

Preview uses the same bounded XML and semantic parsing boundary as inspection:
byte, point, XML depth and element limits, encoding checks, namespace checks,
DOCTYPE rejection, and GPX 1.0/1.1 handling all apply before counting changes.
Failures return zero counts, `output_would_be_empty = false` (the outcome is
unknown), and safe diagnostics. Successful previews may contain informational
diagnostics for omitted empty tracks/routes and a warning for an empty result.

Counts have these meanings:

- `points_removed`: point objects inside the circle across tracks, routes, and
  standalone waypoints.
- `segments_created`: additional retained runs beyond the first in each original
  track segment. A no-op, leading/trailing removal, or fully removed segment
  creates zero additional segments. Original segment boundaries stay separate.
- `routes_removed`: routes with no retained points, which would be omitted.
  Removing some route points does not remove a route that still contains points.
- `waypoints_removed`: standalone waypoint objects removed by the circle; these
  also contribute to `points_removed`.
- `metadata_fields_removed`: present fields selected for explicit removal on
  retained objects plus document-level metadata. Duplicate category selections
  count once. Fields lost with removed points, empty routes/tracks, or empty
  segments do not contribute again. Each selected extensions container counts
  once, not once per opaque XML child or per new segment. Links count individually.
- `output_would_be_empty`: no track point, route point, or waypoint remains,
  regardless of document metadata. A later writer must skip such an output.

Preview is deterministic and does not mutate caller bytes or options. It does
not write, create directories, or read the input path: `source_path` is only the
caller-supplied label. The API package imports no filesystem functionality;
filesystem assertions live in a separate integration-test package.

Diagnostics expose static explanations and codes, never raw coordinates,
timestamps, metadata values, or parser messages. Structured source path labels
are retained for local attribution; their default string rendering omits paths.
The preview contains no redacted bytes. Actual transformation and writing are
separate operations, and retained coordinates can still reveal private places.

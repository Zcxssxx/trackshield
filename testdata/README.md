# Test data provenance

Every GPX file in this directory is original, hand-authored synthetic test
data created for TrackShield. No upstream fixtures, recorded activities,
personal data, or copied route geometry are used. The numeric coordinates are
small deterministic test values chosen to exercise the default 500 metre and
three-distinct-file audit thresholds; they are not observations from a person
or a real activity.

## Collections

- `qualifying/` contains three distinct files. Their start points fall within
  one 500 metre component, while the end points are over 500 metres apart from
  each other and from the start component. A default audit reports exactly one
  repeated-location finding.
- `below-threshold/` contains two distinct files with nearby start points.
  Their component has support from only two files, so the default minimum of
  three files produces no repeated-location finding.

The CLI integration test audits both checked-in collections, repeats the
qualifying audit to compare output bytes, and reverses explicit input order to
check deterministic report output.

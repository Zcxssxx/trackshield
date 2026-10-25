///|
fn report_options(include_coordinates : Bool) -> @model.AuditOptions {
  @model.make_audit_options(500.0, 3, include_coordinates).unwrap()
}

///|
fn empty_report() -> @model.AuditReport {
  @model.make_audit_report(report_options(false), [], [], [])
}

///|
fn report_location(
  id : String,
  evidence : Array[@model.EndpointEvidence],
  center : @model.GeoPoint?,
  max_distance : Double?,
  wide : Bool,
) -> @model.RepeatedLocation {
  @model.make_repeated_location(
    id,
    evidence.length(),
    evidence.length(),
    evidence,
    center,
    max_distance,
    wide,
  )
}

///|
test "empty report JSON and text are stable" {
  let report = empty_report()
  assert_eq(
    @report.render_json(report),
    "{\"options\":{\"radius_m\":500,\"min_distinct_files\":3,\"include_coordinates\":false},\"repeated_locations\":[],\"metadata_findings\":[],\"diagnostics\":[]}",
  )
  assert_eq(
    @report.render_text(report),
    "TrackShield privacy audit\n\nEndpoint radius: 500 m\nMinimum distinct files: 3\nCoordinates: hidden\n\nRepeated endpoint clues\n- none\n\nMetadata exposure\n- none\n\nDiagnostics\n- none\n\nPrivacy note: repeated endpoints are clues only; they do not identify a home or workplace and do not prove anonymity.\n",
  )
}

///|
test "cluster and metadata report uses stable ordering and hides center by default" {
  let center = @model.make_geo_point(1.25, -2.5).unwrap()
  let location = report_location(
    "location-1",
    [
      @model.make_endpoint_evidence("b.gpx", 2, End, 3),
      @model.make_endpoint_evidence("a.gpx", 1, Start, 0),
      @model.make_endpoint_evidence("c.gpx", 3, Start, 1),
    ],
    Some(center),
    Some(125.5),
    false,
  )
  let report = @model.make_audit_report(
    report_options(false),
    [location],
    [
      @model.make_metadata_finding("z.gpx", TrackName, 2, 1),
      @model.make_metadata_finding("a.gpx", PointTimestamp, 2, 0),
      @model.make_metadata_finding("a.gpx", MetadataName, 1, 1),
    ],
    [],
  )
  assert_eq(
    @report.render_json(report),
    "{\"options\":{\"radius_m\":500,\"min_distinct_files\":3,\"include_coordinates\":false},\"repeated_locations\":[{\"id\":\"location-1\",\"distinct_file_count\":3,\"distinct_track_count\":3,\"evidence\":[{\"source_path\":\"a.gpx\",\"track_ordinal\":1,\"kind\":\"start\",\"observation_index\":0},{\"source_path\":\"b.gpx\",\"track_ordinal\":2,\"kind\":\"end\",\"observation_index\":3},{\"source_path\":\"c.gpx\",\"track_ordinal\":3,\"kind\":\"start\",\"observation_index\":1}],\"center\":null,\"max_distance_from_center_m\":125.5,\"wide_component\":false}],\"metadata_findings\":[{\"source_path\":\"a.gpx\",\"category\":\"metadata_name\",\"item_ordinal\":1,\"occurrence_count\":1},{\"source_path\":\"a.gpx\",\"category\":\"point_timestamp\",\"item_ordinal\":2,\"occurrence_count\":0},{\"source_path\":\"z.gpx\",\"category\":\"track_name\",\"item_ordinal\":2,\"occurrence_count\":1}],\"diagnostics\":[]}",
  )
  let text = @report.render_text(report)
  assert_true(text.contains("Maximum center distance: 125.5 m"))
  assert_true(text.contains("timestamp absent at point 2"))
  assert_false(text.contains("1.25"))
  assert_false(text.contains("-2.5"))
}

///|
test "wide chained component and warning appear in the text report" {
  let location = report_location(
    "location-1",
    [
      @model.make_endpoint_evidence("a.gpx", 1, Start, 0),
      @model.make_endpoint_evidence("b.gpx", 1, Start, 0),
      @model.make_endpoint_evidence("c.gpx", 1, Start, 0),
    ],
    None,
    Some(2_750.0),
    true,
  )
  let report = @model.make_audit_report(report_options(false), [location], [], [
    @model.Diagnostic::new(
      @model.code_wide_endpoint_component,
      @model.Warning,
      "",
      "a transitive endpoint component extends beyond the configured radius",
    ),
  ])
  let text = @report.render_text(report)
  assert_true(text.contains("Wide component: yes"))
  assert_true(text.contains("Maximum center distance: 2750 m"))
  assert_true(text.contains("audit.wide_endpoint_component"))
  assert_true(text.contains("do not prove anonymity"))
}

///|
test "partial parse diagnostics render in deterministic JSON" {
  let report = @model.make_audit_report(report_options(false), [], [], [
    @model.Diagnostic::new(
      @model.code_gpx_parse_failed,
      @model.Error,
      "broken.gpx",
      "GPX document could not be parsed",
    ),
  ])
  assert_eq(
    @report.render_json(report),
    "{\"options\":{\"radius_m\":500,\"min_distinct_files\":3,\"include_coordinates\":false},\"repeated_locations\":[],\"metadata_findings\":[],\"diagnostics\":[{\"code\":\"gpx.parse_failed\",\"severity\":\"error\",\"path\":\"broken.gpx\",\"message\":\"GPX document could not be parsed\"}]}",
  )
}

///|
test "coordinate opt-in JSON includes only the stable center" {
  let center = @model.make_geo_point(42.5, -73.25).unwrap()
  let location = report_location(
    "location-1",
    [
      @model.make_endpoint_evidence("a.gpx", 1, Start, 0),
      @model.make_endpoint_evidence("b.gpx", 2, End, 1),
      @model.make_endpoint_evidence("c.gpx", 3, Start, 2),
    ],
    Some(center),
    Some(25.0),
    false,
  )
  let report = @model.make_audit_report(report_options(true), [location], [], [])
  let encoded = @report.render_json(report)
  assert_true(
    encoded.contains("\"center\":{\"latitude\":42.5,\"longitude\":-73.25}"),
  )
  assert_false(encoded.contains("\"latitude\":5.0,\"longitude\":6.0"))
  ignore(@json.parse(encoded))
}

///|
test "JSON strings escape quotes slashes controls and preserve Unicode" {
  let unusual = "quote\" slash\\ line\n tab\t control\u{1} 雪"
  let report = @model.make_audit_report(
    report_options(false),
    [],
    [@model.make_metadata_finding(unusual, Creator, 1, 1)],
    [@model.Diagnostic::new("test.escape", @model.Warning, unusual, unusual)],
  )
  let encoded = @report.render_json(report)
  ignore(@json.parse(encoded))
  assert_true(
    encoded.contains("quote\\\" slash\\\\ line\\n tab\\t control\\u0001 雪"),
  )
}

///|
test "report arrays render identically after input order changes" {
  let first_location = report_location(
    "location-1",
    [
      @model.make_endpoint_evidence("c.gpx", 1, End, 3),
      @model.make_endpoint_evidence("a.gpx", 1, Start, 0),
    ],
    None,
    Some(10.0),
    false,
  )
  let second_location = report_location(
    "location-2",
    [@model.make_endpoint_evidence("b.gpx", 2, Start, 4)],
    None,
    None,
    false,
  )
  let first_diagnostic = @model.Diagnostic::new(
    "z.code",
    @model.Warning,
    "z.gpx",
    "later diagnostic",
  )
  let second_diagnostic = @model.Diagnostic::new(
    "a.code",
    @model.Error,
    "a.gpx",
    "earlier diagnostic",
  )
  let first = @model.make_audit_report(
    report_options(false),
    [first_location, second_location],
    [
      @model.make_metadata_finding("z.gpx", TrackName, 1, 1),
      @model.make_metadata_finding("a.gpx", Creator, 1, 1),
    ],
    [first_diagnostic, second_diagnostic],
  )
  let second = @model.make_audit_report(
    report_options(false),
    [second_location, first_location],
    [
      @model.make_metadata_finding("a.gpx", Creator, 1, 1),
      @model.make_metadata_finding("z.gpx", TrackName, 1, 1),
    ],
    [second_diagnostic, first_diagnostic],
  )
  assert_eq(@report.render_json(first), @report.render_json(second))
  assert_eq(@report.render_text(first), @report.render_text(second))
}

///|
test "default rendering never contains endpoint coordinates or metadata values" {
  let center = @model.make_geo_point(5.005, 6.005).unwrap()
  let location = report_location(
    "location-1",
    [@model.make_endpoint_evidence("private-activity.gpx", 1, Start, 0)],
    Some(center),
    Some(800.0),
    false,
  )
  let report = @model.make_audit_report(
    report_options(false),
    [location],
    [@model.make_metadata_finding("private-activity.gpx", AuthorEmail, 1, 1)],
    [],
  )
  let encoded = @report.render_json(report)
  for
    secret in [
      "5.0,6.0", "5.01,6.01", "Private Athlete", "athlete@example.invalid", "https://private.invalid",
      "2026-10-25T07:30:00Z",
    ] {
    assert_false(encoded.contains(secret))
  }
}

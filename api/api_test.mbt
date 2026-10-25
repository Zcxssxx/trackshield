///|
test "public API re-exports validated constructors and defaults" {
  let point = match @api.make_geo_point(12.5, -44.25) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  assert_eq(point.latitude, 12.5)
  assert_eq(point.longitude, -44.25)
  let options = @api.default_audit_options()
  assert_eq(options.radius_m, 500.0)
  assert_eq(options.min_distinct_files, 3)
  assert_eq(options.include_coordinates, false)
  let limits = match @api.make_input_limits(4096, 100, 8, 8192, 64, 1000) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  assert_eq(limits.max_xml_elements, 1000)
  let input = @api.GpxInput::new("sample.gpx", Bytes::from_array([]))
  assert_eq(input.path, "sample.gpx")
  let center = match @api.make_geo_point(0.0, 0.0) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  let redaction = match
    @api.make_redaction_options(center, 250.0, [
      @api.MetadataCategory::TrackName,
    ]) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  assert_eq(redaction.remove_metadata.length(), 1)
}

///|
test "public API exposes an empty collection audit" {
  let report = @api.audit_collection([], @api.default_audit_options())
  assert_eq(report.repeated_locations.length(), 0)
  assert_eq(report.metadata_findings.length(), 0)
  assert_eq(report.options.min_distinct_files, 3)
}

///|
fn test_bytes(text : String) -> Bytes {
  let bytes : Array[Byte] = []
  for ch in text {
    bytes.push(ch.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn test_limits(max_points_per_file : Int32) -> @api.InputLimits {
  @api.make_input_limits(8192, max_points_per_file, 10, 16384, 64, 1000).unwrap()
}

///|
fn inspect_text(
  source : String,
  limits : @api.InputLimits,
) -> @api.FileInspection {
  inspect_text_at("runner-42.gpx", source, limits)
}

///|
fn inspect_text_at(
  path : String,
  source : String,
  limits : @api.InputLimits,
) -> @api.FileInspection {
  @api.inspect_gpx(@api.GpxInput::new(path, test_bytes(source)), limits)
}

///|
fn has_metadata(
  findings : Array[@api.MetadataFinding],
  category : @api.MetadataCategory,
) -> Bool {
  for finding in findings {
    if finding.category.to_string() == category.to_string() {
      return true
    }
  }
  false
}

///|
fn count_metadata(
  findings : Array[@api.MetadataFinding],
  category : @api.MetadataCategory,
) -> Int32 {
  let mut count = 0
  for finding in findings {
    if finding.category.to_string() == category.to_string() {
      count += finding.occurrence_count
    }
  }
  count
}

///|
fn has_metadata_ordinal(
  findings : Array[@api.MetadataFinding],
  category : @api.MetadataCategory,
  ordinal : Int32,
) -> Bool {
  for finding in findings {
    if finding.category.to_string() == category.to_string() &&
      finding.item_ordinal == ordinal {
      return true
    }
  }
  false
}

///|
fn fixture_multiple_tracks() -> String {
  (
    #|<gpx version="1.1" creator="TrackShield test" xmlns="http://www.topografix.com/GPX/1/1">
    #|  <trk><trkseg/><trkseg><trkpt lat="10" lon="20"/><trkpt lat="11" lon="21"/></trkseg><trkseg/></trk>
    #|  <trk><trkseg><trkpt lat="12" lon="22"/></trkseg></trk>
    #|  <trk><trkseg/></trk>
    #|</gpx>
  )
}

///|
fn fixture_metadata_gpx() -> String {
  (
    #|<gpx version="1.1" creator="private creator marker" xmlns="http://www.topografix.com/GPX/1/1">
    #|  <metadata>
    #|    <name>private metadata name</name><desc>private metadata description</desc>
    #|    <author><name>private author</name><email id="private" domain="example.invalid"/></author>
    #|    <link href="https://private.invalid"><text>private link label</text></link>
    #|    <extensions><secret xmlns="urn:trackshield:test">opaque metadata extension</secret></extensions>
    #|  </metadata>
    #|  <wpt lat="1" lon="2"><time>2026-01-01T00:00:00Z</time><name>private waypoint</name><desc>private waypoint description</desc></wpt>
    #|  <rte><name>private route</name><desc>private route description</desc><rtept lat="3" lon="4"><name>private route point</name></rtept></rte>
    #|  <trk>
    #|    <name>private track</name><desc>private track description</desc><link href="https://track.invalid"/>
    #|    <extensions><device xmlns="urn:trackshield:test">opaque track extension</device></extensions>
    #|    <trkseg><trkpt lat="5" lon="6"><time>2026-01-02T00:00:00Z</time><name>private track point</name><desc>private point description</desc><extensions><device xmlns="urn:trackshield:test">opaque point extension</device></extensions></trkpt></trkseg>
    #|  </trk>
    #|</gpx>
  )
}

///|
fn fixture_gpx_10_route_and_waypoint() -> String {
  (
    #|<gpx version="1.0" creator="legacy creator" xmlns="http://www.topografix.com/GPX/1/0">
    #|  <name>legacy metadata name</name><desc>legacy metadata description</desc>
    #|  <author>legacy author</author><email>legacy@example.invalid</email>
    #|  <url>https://legacy.invalid</url><urlname>legacy link</urlname>
    #|  <wpt lat="11" lon="21"><name>waypoint only</name></wpt>
    #|  <rte><name>route only</name><rtept lat="10" lon="20"/></rte>
    #|</gpx>
  )
}

///|
test "inspection returns endpoints across empty segments and empty tracks" {
  let inspection = inspect_text(fixture_multiple_tracks(), test_limits(10))
  if !inspection.analyzed {
    fail(inspection.diagnostics[0].to_string())
  }
  assert_eq(inspection.track_count, 3)
  assert_eq(inspection.point_count, 3)
  assert_eq(inspection.endpoints.length(), 4)
  assert_eq(inspection.endpoints[0].track_ordinal, 1)
  assert_eq(inspection.endpoints[0].kind.to_string(), "start")
  assert_eq(inspection.endpoints[0].point.latitude, 10.0)
  assert_eq(inspection.endpoints[1].kind.to_string(), "end")
  assert_eq(inspection.endpoints[1].point.longitude, 21.0)
  assert_eq(inspection.endpoints[2].track_ordinal, 2)
  assert_eq(inspection.endpoints[2].point.latitude, 12.0)
  assert_eq(inspection.endpoints[3].point.longitude, 22.0)
  assert_eq(inspection.endpoints[0].source_path, "runner-42.gpx")
}

///|
test "timestamp coverage records missing and present times per point" {
  let limits = test_limits(10)
  let zero = inspect_text_at("zero.gpx", fixture_multiple_tracks(), limits)
  let partial = inspect_text_at("partial.gpx", fixture_metadata_gpx(), limits)
  let complete = inspect_text_at(
    "complete.gpx",
    (
      #|<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">
      #|  <trk><trkseg>
      #|    <trkpt lat="50" lon="60"><time>2026-01-01T00:00:00Z</time></trkpt>
      #|    <trkpt lat="51" lon="61"><time>2026-01-02T00:00:00Z</time></trkpt>
      #|  </trkseg></trk>
      #|</gpx>
    ),
    limits,
  )
  assert_true(zero.analyzed && partial.analyzed && complete.analyzed)
  assert_eq(zero.point_count, 3)
  assert_eq(
    count_metadata(
      zero.metadata_findings,
      @api.MetadataCategory::PointTimestamp,
    ),
    0,
  )
  assert_eq(count_timestamp_records(zero.metadata_findings), 3)
  assert_eq(partial.point_count, 3)
  assert_eq(
    count_metadata(
      partial.metadata_findings,
      @api.MetadataCategory::PointTimestamp,
    ),
    2,
  )
  assert_eq(count_timestamp_records(partial.metadata_findings), 3)
  assert_eq(complete.point_count, 2)
  assert_eq(
    count_metadata(
      complete.metadata_findings,
      @api.MetadataCategory::PointTimestamp,
    ),
    2,
  )
  assert_eq(count_timestamp_records(complete.metadata_findings), 2)

  let report = @api.audit_collection(
    [zero, partial, complete],
    @api.default_audit_options(),
  )
  assert_eq(
    count_metadata_records(
      report.metadata_findings,
      @api.MetadataCategory::PointTimestamp,
    ),
    8,
  )
  assert_eq(
    count_metadata(
      report.metadata_findings,
      @api.MetadataCategory::PointTimestamp,
    ),
    4,
  )
}

///|
test "collection metadata findings omit GPX values and exact coordinates" {
  let inspection = inspect_text_at(
    "sensitive.gpx",
    fixture_metadata_gpx(),
    test_limits(10),
  )
  assert_true(inspection.analyzed)
  let report = @api.audit_collection([inspection], @api.default_audit_options())
  let mut exposed_text = ""
  for finding in report.metadata_findings {
    exposed_text += finding.source_path +
      ":" +
      finding.category.to_string() +
      ":" +
      finding.item_ordinal.to_string() +
      ":" +
      finding.occurrence_count.to_string() +
      ";"
  }
  assert_false(exposed_text.contains("private creator marker"))
  assert_false(exposed_text.contains("private metadata name"))
  assert_false(exposed_text.contains("private author"))
  assert_false(exposed_text.contains("private@example.invalid"))
  assert_false(exposed_text.contains("https://private.invalid"))
  assert_false(exposed_text.contains("2026-01-02T00:00:00Z"))
  assert_false(exposed_text.contains("lat=\"5\" lon=\"6\""))
}

///|
test "identical metadata values from different files keep separate evidence" {
  let first = inspect_text_at("a.gpx", fixture_metadata_gpx(), test_limits(10))
  let second = inspect_text_at("b.gpx", fixture_metadata_gpx(), test_limits(10))
  let report = @api.audit_collection(
    [first, second],
    @api.default_audit_options(),
  )
  let paths : Array[String] = []
  for finding in report.metadata_findings {
    if finding.category.to_string() ==
      @api.MetadataCategory::MetadataName.to_string() &&
      finding.item_ordinal == 1 {
      paths.push(finding.source_path)
    }
  }
  assert_eq(paths.length(), 2)
  assert_eq(paths[0], "a.gpx")
  assert_eq(paths[1], "b.gpx")
}

///|
fn count_timestamp_records(findings : Array[@api.MetadataFinding]) -> Int32 {
  count_metadata_records(findings, @api.MetadataCategory::PointTimestamp)
}

///|
fn count_metadata_records(
  findings : Array[@api.MetadataFinding],
  category : @api.MetadataCategory,
) -> Int32 {
  let mut count = 0
  for finding in findings {
    if finding.category.to_string() == category.to_string() {
      count += 1
    }
  }
  count
}

///|
test "inspection counts metadata categories without copying source values" {
  let inspection = inspect_text(fixture_metadata_gpx(), test_limits(100))
  if !inspection.analyzed {
    fail(inspection.diagnostics[0].to_string())
  }
  assert_true(
    has_metadata(inspection.metadata_findings, @api.MetadataCategory::Creator),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::MetadataName,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::MetadataDescription,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::AuthorName,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::AuthorEmail,
    ),
  )
  assert_true(
    has_metadata(inspection.metadata_findings, @api.MetadataCategory::Link),
  )
  assert_true(
    has_metadata(inspection.metadata_findings, @api.MetadataCategory::TrackName),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::TrackDescription,
    ),
  )
  assert_true(
    has_metadata(inspection.metadata_findings, @api.MetadataCategory::RouteName),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::RouteDescription,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::WaypointName,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::WaypointDescription,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::PointTimestamp,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::Extensions,
    ),
  )
  assert_eq(
    count_metadata(inspection.metadata_findings, @api.MetadataCategory::Link),
    2,
  )
  assert_eq(
    count_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::Extensions,
    ),
    3,
  )
  assert_eq(
    count_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::PointTimestamp,
    ),
    2,
  )
  let mut missing_timestamp_presence = None
  for finding in inspection.metadata_findings {
    if finding.category.to_string() ==
      @api.MetadataCategory::PointTimestamp.to_string() &&
      finding.item_ordinal == 2 {
      missing_timestamp_presence = Some(finding.occurrence_count)
    }
  }
  assert_eq(missing_timestamp_presence, Some(0))
  assert_true(
    has_metadata_ordinal(
      inspection.metadata_findings,
      @api.MetadataCategory::TrackName,
      1,
    ),
  )
  assert_true(
    has_metadata_ordinal(
      inspection.metadata_findings,
      @api.MetadataCategory::WaypointName,
      3,
    ),
  )
  assert_eq(inspection.metadata_findings[0].occurrence_count, 1)
  assert_eq(inspection.diagnostics.length(), 0)
}

///|
test "GPX 1.0 metadata is mapped and routes do not create endpoint observations" {
  let inspection = inspect_text(
    fixture_gpx_10_route_and_waypoint(),
    test_limits(100),
  )
  if !inspection.analyzed {
    fail(inspection.diagnostics[0].to_string())
  }
  assert_eq(inspection.track_count, 0)
  assert_eq(inspection.point_count, 2)
  assert_eq(inspection.endpoints.length(), 0)
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::MetadataName,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::MetadataDescription,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::AuthorName,
    ),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::AuthorEmail,
    ),
  )
  assert_true(
    has_metadata(inspection.metadata_findings, @api.MetadataCategory::Link),
  )
  assert_true(
    has_metadata(
      inspection.metadata_findings,
      @api.MetadataCategory::WaypointName,
    ),
  )
}

///|
test "preflight failures are returned before semantic parsing" {
  let doctype = inspect_text(
    "<!DOCTYPE gpx><gpx version=\"1.1\" creator=\"x\"/>",
    test_limits(10),
  )
  assert_false(doctype.analyzed)
  assert_eq(doctype.diagnostics.length(), 1)
  assert_eq(doctype.diagnostics[0].code, @api.code_doctype_forbidden)
  assert_eq(doctype.diagnostics[0].path, "runner-42.gpx")
  assert_true(!doctype.diagnostics[0].to_string().contains("runner-42.gpx"))

  let oversized = @api.GpxInput::new("large.gpx", Bytes::make(17, b'x'))
  let tiny_limits = match @api.make_input_limits(16, 10, 10, 32, 64, 100) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  let size_result = @api.inspect_gpx(oversized, tiny_limits)
  assert_false(size_result.analyzed)
  assert_eq(size_result.diagnostics[0].code, @api.code_file_too_large)
}

///|
test "UTF-8 BOM is accepted and removed before semantic parsing" {
  let source = "<gpx version=\"1.1\" creator=\"bom fixture\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg><trkpt lat=\"1\" lon=\"2\"/></trkseg></trk></gpx>"
  let bytes = Bytes::from_array([
      (0xEF).to_byte(),
      (0xBB).to_byte(),
      (0xBF).to_byte(),
    ]) +
    test_bytes(source)
  let inspection = @api.inspect_gpx(
    @api.GpxInput::new("bom.gpx", bytes),
    test_limits(10),
  )
  assert_true(inspection.analyzed)
  assert_eq(inspection.endpoints.length(), 2)
}

///|
test "mixed core namespaces are rejected by preflight" {
  let source = "<gpx version=\"1.1\" creator=\"x\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk xmlns=\"urn:unexpected\"/></gpx>"
  let inspection = inspect_text(source, test_limits(10))
  assert_false(inspection.analyzed)
  assert_eq(inspection.diagnostics[0].code, @api.code_unsupported_namespace)
}

///|
test "point limits reject a parsed file without returning partial observations" {
  let source = "<gpx version=\"1.1\" creator=\"x\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg><trkpt lat=\"1\" lon=\"2\"/><trkpt lat=\"3\" lon=\"4\"/></trkseg></trk></gpx>"
  let exact = inspect_text(source, test_limits(2))
  assert_true(exact.analyzed)
  assert_eq(exact.point_count, 2)

  let inspection = inspect_text(source, test_limits(1))
  assert_false(inspection.analyzed)
  assert_eq(inspection.endpoints.length(), 0)
  assert_eq(inspection.point_count, 0)
  assert_eq(inspection.diagnostics[0].code, @api.code_point_limit_exceeded)
}

///|
test "malformed GPX returns a safe diagnostic rather than throwing" {
  let inspection = inspect_text(
    "<gpx version=\"1.1\" creator=\"SECRET CREATOR\"><trk></gpx>",
    test_limits(10),
  )
  assert_false(inspection.analyzed)
  assert_true(inspection.diagnostics.length() > 0)
  assert_eq(inspection.diagnostics[0].code, @api.code_invalid_xml)
  assert_true(!inspection.diagnostics[0].to_string().contains("SECRET CREATOR"))
}

///|
test "semantic parser errors are mapped without exposing invalid values" {
  let inspection = inspect_text(
    "<gpx version=\"1.1\" creator=\"private creator\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg><trkpt lat=\"999\" lon=\"2\"/></trkseg></trk></gpx>",
    test_limits(10),
  )
  assert_false(inspection.analyzed)
  assert_eq(inspection.diagnostics[0].code, @api.code_gpx_parse_failed)
  assert_true(!inspection.diagnostics[0].to_string().contains("999"))
  assert_true(
    !inspection.diagnostics[0].to_string().contains("private creator"),
  )
}

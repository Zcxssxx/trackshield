///|
fn audit_test_point(latitude : Double, longitude : Double) -> @model.GeoPoint {
  @model.make_geo_point(latitude, longitude).unwrap()
}

///|
fn endpoint(
  source_path : String,
  track_ordinal : Int32,
  kind : @model.EndpointKind,
  observation_index : Int32,
  latitude : Double,
  longitude : Double,
) -> @model.EndpointObservation {
  @model.make_endpoint_observation(
    source_path,
    track_ordinal,
    kind,
    observation_index,
    audit_test_point(latitude, longitude),
  )
}

///|
fn inspection(
  source_path : String,
  endpoints : Array[@model.EndpointObservation],
  track_count : Int32,
) -> @model.FileInspection {
  @model.make_file_inspection(
    source_path,
    endpoints,
    [],
    [],
    track_count,
    endpoints.length(),
    true,
  )
}

///|
fn options(
  radius_m : Double,
  min_distinct_files : Int32,
  include_coordinates : Bool,
) -> @model.AuditOptions {
  @model.make_audit_options(radius_m, min_distinct_files, include_coordinates).unwrap()
}

///|
test "three distinct source files qualify and coordinates stay private by default" {
  let report = @audit.audit_collection(
    [
      inspection("a.gpx", [endpoint("a.gpx", 1, Start, 0, 37.0, -122.0)], 1),
      inspection("b.gpx", [endpoint("b.gpx", 1, Start, 0, 37.001, -122.0)], 1),
      inspection("c.gpx", [endpoint("c.gpx", 1, End, 1, 37.002, -122.0)], 1),
    ],
    options(500.0, 3, false),
  )
  assert_eq(report.repeated_locations.length(), 1)
  let finding = report.repeated_locations[0]
  assert_eq(finding.distinct_file_count, 3)
  assert_eq(finding.distinct_track_count, 3)
  assert_eq(finding.evidence.length(), 3)
  assert_true(finding.center is None)
  assert_true(finding.max_distance_from_center_m is Some(_))
  assert_false(finding.wide_component)
}

///|
test "two distinct source files do not meet the default support threshold" {
  let report = @audit.audit_collection(
    [
      inspection("a.gpx", [endpoint("a.gpx", 1, Start, 0, 0.0, 0.0)], 1),
      inspection("b.gpx", [endpoint("b.gpx", 1, End, 1, 0.0, 0.0)], 1),
    ],
    options(500.0, 3, false),
  )
  assert_eq(report.repeated_locations.length(), 0)
}

///|
test "multiple tracks in one file count as one distinct source" {
  let report = @audit.audit_collection(
    [
      inspection(
        "a.gpx",
        [
          endpoint("a.gpx", 1, Start, 0, 0.0, 0.0),
          endpoint("a.gpx", 2, Start, 1, 0.0, 0.0),
          endpoint("a.gpx", 3, End, 2, 0.0, 0.0),
        ],
        3,
      ),
      inspection("b.gpx", [endpoint("b.gpx", 1, Start, 0, 0.0, 0.0)], 1),
    ],
    options(500.0, 3, false),
  )
  assert_eq(report.repeated_locations.length(), 0)
}

///|
test "duplicate normalized source paths do not inflate file support" {
  let report = @audit.audit_collection(
    [
      inspection(
        "folder/a.gpx",
        [endpoint("alias/first.gpx", 1, Start, 0, 0.0, 0.0)],
        1,
      ),
      inspection(
        "folder/a.gpx",
        [endpoint("alias/second.gpx", 2, Start, 1, 0.0, 0.0)],
        1,
      ),
      inspection(
        "folder/b.gpx",
        [endpoint("folder/b.gpx", 1, Start, 0, 0.0, 0.0)],
        1,
      ),
    ],
    options(500.0, 3, false),
  )
  assert_eq(report.repeated_locations.length(), 0)
}

///|
test "transitive proximity keeps a wide component and emits a stable warning" {
  let report = @audit.audit_collection(
    [
      inspection("a.gpx", [endpoint("a.gpx", 1, Start, 0, 0.0, 0.0)], 1),
      inspection("b.gpx", [endpoint("b.gpx", 1, Start, 0, 0.0, 0.004)], 1),
      inspection("c.gpx", [endpoint("c.gpx", 1, Start, 0, 0.0, 0.008)], 1),
      inspection("d.gpx", [endpoint("d.gpx", 1, Start, 0, 0.0, 0.012)], 1),
    ],
    options(500.0, 3, false),
  )
  assert_eq(report.repeated_locations.length(), 1)
  let finding = report.repeated_locations[0]
  assert_true(finding.wide_component)
  assert_eq(finding.evidence.length(), 4)
  assert_true(finding.max_distance_from_center_m.unwrap() > 500.0)
  assert_true(
    report.diagnostics.any(d => d.code == "audit.wide_endpoint_component"),
  )
}

///|
test "exact configured pair distance is included in a component" {
  let west = audit_test_point(0.0, 0.0)
  let east = audit_test_point(0.0, 0.001)
  let radius = @geo.distance_m(west, east)
  let report = @audit.audit_collection(
    [
      inspection("a.gpx", [endpoint("a.gpx", 1, Start, 0, 0.0, 0.0)], 1),
      inspection("b.gpx", [endpoint("b.gpx", 1, Start, 0, 0.0, 0.001)], 1),
    ],
    options(radius, 2, true),
  )
  assert_eq(report.repeated_locations.length(), 1)
  assert_false(report.repeated_locations[0].wide_component)
  assert_true(report.repeated_locations[0].center is Some(_))
}

///|
test "identical endpoints qualify and an empty collection returns no findings" {
  let report = @audit.audit_collection(
    [
      inspection("a.gpx", [endpoint("a.gpx", 1, Start, 0, 45.0, 10.0)], 1),
      inspection("b.gpx", [endpoint("b.gpx", 1, End, 1, 45.0, 10.0)], 1),
    ],
    options(1.0, 2, true),
  )
  assert_eq(report.repeated_locations.length(), 1)
  assert_eq(report.repeated_locations[0].max_distance_from_center_m, Some(0.0))
  let empty = @audit.audit_collection([], options(500.0, 3, false))
  assert_eq(empty.repeated_locations.length(), 0)
}

///|
test "two ends of one track remain evidence without inflating track count" {
  let report = @audit.audit_collection(
    [
      inspection(
        "a.gpx",
        [
          endpoint("a.gpx", 1, Start, 0, 0.0, 0.0),
          endpoint("a.gpx", 1, End, 1, 0.0, 0.001),
        ],
        1,
      ),
      inspection("b.gpx", [endpoint("b.gpx", 1, Start, 0, 0.0, 0.0)], 1),
      inspection("c.gpx", [endpoint("c.gpx", 1, Start, 0, 0.0, 0.001)], 1),
    ],
    options(500.0, 3, false),
  )
  assert_eq(report.repeated_locations.length(), 1)
  assert_eq(report.repeated_locations[0].distinct_file_count, 3)
  assert_eq(report.repeated_locations[0].distinct_track_count, 3)
  assert_eq(report.repeated_locations[0].evidence.length(), 4)
}

///|
test "unanalyzed files preserve their diagnostic and add no endpoint evidence" {
  let invalid_inspection = @model.make_file_inspection(
    "a.gpx",
    [],
    [],
    [
      @model.Diagnostic::new(
        @model.code_invalid_latitude,
        @model.Error,
        "a.gpx",
        "latitude must be between -90 and 90 degrees",
      ),
    ],
    1,
    0,
    false,
  )
  let report = @audit.audit_collection(
    [
      invalid_inspection,
      inspection("b.gpx", [endpoint("b.gpx", 1, Start, 0, 0.0, 0.0)], 1),
      inspection("c.gpx", [endpoint("c.gpx", 1, Start, 0, 0.0, 0.0)], 1),
    ],
    options(500.0, 3, false),
  )
  assert_eq(report.repeated_locations.length(), 0)
  assert_true(
    report.diagnostics.any(d => d.code == @model.code_invalid_latitude),
  )
}

///|
test "an antipodal supported component reports its undefined center" {
  let east = audit_test_point(0.0, 0.0)
  let west = audit_test_point(0.0, 180.0)
  assert_true(@geo.distance_m(east, west) < 20_037_508.0)
  let report = @audit.audit_collection(
    [
      inspection("a.gpx", [endpoint("a.gpx", 1, Start, 0, 0.0, 0.0)], 1),
      inspection("b.gpx", [endpoint("b.gpx", 1, Start, 0, 0.0, 180.0)], 1),
    ],
    options(20_037_508.0, 2, true),
  )
  assert_eq(report.repeated_locations.length(), 1)
  assert_true(report.repeated_locations[0].center is None)
  assert_true(report.repeated_locations[0].max_distance_from_center_m is None)
  assert_false(report.repeated_locations[0].wide_component)
  assert_true(
    report.diagnostics.any(d => d.code == @model.code_undefined_center),
  )
}

///|
fn finding_summary(report : @model.AuditReport) -> String {
  let mut summary = ""
  for finding in report.repeated_locations {
    summary += finding.id +
      ":" +
      finding.distinct_file_count.to_string() +
      ":" +
      finding.distinct_track_count.to_string() +
      ":" +
      finding.wide_component.to_string() +
      ":"
    summary += match finding.max_distance_from_center_m {
      Some(distance) => distance.to_string()
      None => "undefined"
    }
    summary += match finding.center {
      Some(center) =>
        ":" + center.latitude.to_string() + "," + center.longitude.to_string()
      None => ":hidden"
    }
    summary += ":"
    for evidence in finding.evidence {
      summary += evidence.source_path +
        "/" +
        evidence.track_ordinal.to_string() +
        "/" +
        evidence.kind.to_string() +
        "/" +
        evidence.observation_index.to_string() +
        ";"
    }
  }
  for diagnostic in report.diagnostics {
    summary += diagnostic.code +
      ":" +
      diagnostic.path +
      ":" +
      diagnostic.severity.to_string() +
      ":" +
      diagnostic.message +
      ";"
  }
  summary
}

///|
test "input order permutations produce deterministic findings and diagnostics" {
  let a = inspection("a.gpx", [endpoint("a.gpx", 1, Start, 0, 1.0, 1.0)], 1)
  let b = inspection("b.gpx", [endpoint("b.gpx", 1, End, 1, 1.001, 1.0)], 1)
  let c = inspection("c.gpx", [endpoint("c.gpx", 1, Start, 0, 1.002, 1.0)], 1)
  let first = @audit.audit_collection([a, b, c], options(500.0, 3, false))
  let second = @audit.audit_collection([c, a, b], options(500.0, 3, false))
  assert_eq(finding_summary(first), finding_summary(second))
}

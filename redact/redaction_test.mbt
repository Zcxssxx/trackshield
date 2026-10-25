///|
fn input(body : String) -> @model.GpxInput {
  @model.GpxInput::new(
    "preview-source.gpx",
    @utf8.encode(
      "<gpx version=\"1.1\" creator=\"secret creator\" xmlns=\"http://www.topografix.com/GPX/1/1\">" +
      body +
      "</gpx>",
    ),
  )
}

///|
fn options(
  categories : Array[@model.MetadataCategory],
) -> @model.RedactionOptions {
  @model.make_redaction_options(
    @model.make_geo_point(0.0, 0.0).unwrap(),
    1000.0,
    categories,
  ).unwrap()
}

///|
fn preview(
  body : String,
  categories : Array[@model.MetadataCategory],
) -> @model.RedactionPreview {
  @redact.preview_redaction(
    input(body),
    options(categories),
    @model.default_input_limits(),
  )
}

///|
test "no-op preserves separate segments and creates no additional segments" {
  let result = preview(
    "<trk><trkseg/><trkseg><trkpt lat=\"1\" lon=\"1\"/></trkseg><trkseg><trkpt lat=\"2\" lon=\"2\"/></trkseg></trk>",
    [],
  )
  assert_eq(result.points_removed, 0)
  assert_eq(result.segments_created, 0)
  assert_eq(result.routes_removed, 0)
  assert_eq(result.waypoints_removed, 0)
  assert_eq(result.metadata_fields_removed, 0)
  assert_false(result.output_would_be_empty)
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "track splits count additional runs only across internal removed gaps" {
  let result = preview(
    "<trk><trkseg><trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"1\" lon=\"1\"/><trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"2\" lon=\"2\"/><trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"3\" lon=\"3\"/><trkpt lat=\"0\" lon=\"0\"/></trkseg><trkseg><trkpt lat=\"4\" lon=\"4\"/></trkseg></trk>",
    [],
  )
  assert_eq(result.points_removed, 5)
  assert_eq(result.segments_created, 2)
  assert_false(result.output_would_be_empty)
}

///|
test "counts all point kinds and omits only routes emptied by filtering" {
  let result = preview(
    "<wpt lat=\"0\" lon=\"0\"/><wpt lat=\"1\" lon=\"1\"/><rte><rtept lat=\"0\" lon=\"0\"/></rte><rte><rtept lat=\"0\" lon=\"0\"/><rtept lat=\"2\" lon=\"2\"/></rte><trk><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg></trk>",
    [],
  )
  assert_eq(result.points_removed, 4)
  assert_eq(result.routes_removed, 1)
  assert_eq(result.waypoints_removed, 1)
  assert_eq(result.segments_created, 0)
  assert_false(result.output_would_be_empty)
}

///|
test "empty result is reported even when metadata remains" {
  let result = preview(
    "<metadata><name>secret name</name></metadata><wpt lat=\"0\" lon=\"0\"/><rte><rtept lat=\"0\" lon=\"0\"/></rte><trk><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg></trk>",
    [],
  )
  assert_eq(result.points_removed, 3)
  assert_true(result.output_would_be_empty)
  assert_eq(result.segments_created, 0)
  assert_true(preview("<trk><trkseg/></trk>", []).output_would_be_empty)
}

///|
test "radius boundary is inclusive and just outside is retained" {
  let center = @model.make_geo_point(0.0, 0.0).unwrap()
  let edge = @model.make_geo_point(0.0, 1.0).unwrap()
  let opts = @model.make_redaction_options(
    center,
    @geo.distance_m(center, edge),
    [],
  ).unwrap()
  let result = @redact.preview_redaction(
    input("<wpt lat=\"0\" lon=\"1\"/><wpt lat=\"0\" lon=\"1.000001\"/>"),
    opts,
    @model.default_input_limits(),
  )
  assert_eq(result.points_removed, 1)
  assert_false(result.output_would_be_empty)
}

///|
test "circle inclusion crosses dateline and converging polar meridians" {
  for
    (latitude, longitude, body) in [
      (0.0, 179.9, "<wpt lat=\"0\" lon=\"-179.9\"/>"),
      (89.9, 0.0, "<wpt lat=\"89.9\" lon=\"90\"/>"),
    ] {
    let opts = @model.make_redaction_options(
      @model.make_geo_point(latitude, longitude).unwrap(),
      25000.0,
      [],
    ).unwrap()
    let result = @redact.preview_redaction(
      input(body),
      opts,
      @model.default_input_limits(),
    )
    assert_eq(result.points_removed, 1)
    assert_true(result.output_would_be_empty)
  }
}

///|
test "duplicate selected categories count once and removed parents contribute no metadata" {
  let result = preview(
    "<wpt lat=\"0\" lon=\"0\"><time>2026-01-01T00:00:00Z</time><name>lost</name></wpt><wpt lat=\"1\" lon=\"1\"><time>2026-01-01T00:00:00Z</time><name>retained</name></wpt><rte><name>lost route</name><rtept lat=\"0\" lon=\"0\"/></rte><trk><name>lost track</name><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg></trk>",
    [
      @model.Creator,
      @model.Creator,
      @model.WaypointName,
      @model.WaypointName,
      @model.PointTimestamp,
      @model.RouteName,
      @model.TrackName,
    ],
  )
  assert_eq(result.metadata_fields_removed, 3)
  assert_eq(result.points_removed, 3)
}

///|
test "all supported metadata categories count present retained fields exactly" {
  let result = preview(
    "<metadata><name>n</name><desc>d</desc><author><name>a</name><email id=\"a\" domain=\"example.invalid\"/><link href=\"https://example.invalid\"/></author><link href=\"https://example.invalid\"/><extensions><x xmlns=\"urn:test\"/></extensions></metadata><wpt lat=\"1\" lon=\"1\"><time>2026-01-01T00:00:00Z</time><name>n</name><desc>d</desc><link href=\"https://example.invalid\"/><extensions><x xmlns=\"urn:test\"/></extensions></wpt><rte><name>n</name><desc>d</desc><rtept lat=\"1\" lon=\"1\"/></rte><trk><name>n</name><desc>d</desc><trkseg><trkpt lat=\"1\" lon=\"1\"/></trkseg></trk><extensions><x xmlns=\"urn:test\"/></extensions>",
    [
      @model.Creator,
      @model.MetadataName,
      @model.MetadataDescription,
      @model.AuthorName,
      @model.AuthorEmail,
      @model.Link,
      @model.TrackName,
      @model.TrackDescription,
      @model.RouteName,
      @model.RouteDescription,
      @model.WaypointName,
      @model.WaypointDescription,
      @model.PointTimestamp,
      @model.Extensions,
    ],
  )
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.metadata_fields_removed, 18)
}

///|
test "invalid centers and radii fail validation without exposing values" {
  for
    (lat, lon) in [
      (91.0, 0.0),
      (0.0, 181.0),
      (0.0 / 0.0, 0.0),
      (0.0, 1.0 / 0.0),
    ] {
    assert_true(@model.make_geo_point(lat, lon) is Err(_))
  }
  let center = @model.make_geo_point(90.0, -180.0).unwrap()
  for radius in [0.0, -1.0, 20_037_509.0, 0.0 / 0.0, 1.0 / 0.0] {
    assert_true(@model.make_redaction_options(center, radius, []) is Err(_))
  }
  assert_true(@model.make_redaction_options(center, 20_037_508.0, []) is Ok(_))
}

///|
test "preflight and semantic errors yield safe zero counts" {
  for
    source in [
      "<!DOCTYPE gpx><gpx/>", "<gpx>", "<gpx version=\"1.1\" creator=\"SECRET\" xmlns=\"http://www.topografix.com/GPX/1/1\"><wpt lat=\"999\" lon=\"0\"/></gpx>",
    ] {
    let result = @redact.preview_redaction(
      @model.GpxInput::new("private.gpx", @utf8.encode(source)),
      options([]),
      @model.default_input_limits(),
    )
    assert_true(result.diagnostics.length() > 0)
    assert_eq(result.points_removed, 0)
    assert_eq(result.metadata_fields_removed, 0)
    assert_false(result.output_would_be_empty)
    for diagnostic in result.diagnostics {
      assert_false(diagnostic.to_string().contains("SECRET"))
      assert_false(diagnostic.to_string().contains("999"))
      assert_false(diagnostic.to_string().contains("private.gpx"))
    }
  }
}

///|
test "preview is deterministic and leaves caller bytes and options unchanged" {
  let data = input("<wpt lat=\"0\" lon=\"0\"/><wpt lat=\"1\" lon=\"1\"/>")
  let before = data.bytes
  let opts = options([@model.Creator, @model.Creator])
  let a = @redact.preview_redaction(data, opts, @model.default_input_limits())
  let b = @redact.preview_redaction(data, opts, @model.default_input_limits())
  assert_eq(a.points_removed, b.points_removed)
  assert_eq(a.metadata_fields_removed, b.metadata_fields_removed)
  assert_eq(a.output_would_be_empty, b.output_would_be_empty)
  assert_eq(a.source_path, "preview-source.gpx")
  assert_eq(data.bytes, before)
  assert_eq(opts.remove_metadata.length(), 2)
}

///|
test "preview inherits byte point XML namespace and encoding limits" {
  let body = "<wpt lat=\"0\" lon=\"0\"/><wpt lat=\"1\" lon=\"1\"/>"
  let point_limit = @model.make_input_limits(4096, 1, 1, 4096, 64, 100).unwrap()
  let byte_limit = @model.make_input_limits(16, 1, 1, 16, 64, 100).unwrap()
  for
    (limits, code) in [
      (point_limit, @model.code_point_limit_exceeded),
      (byte_limit, @model.code_file_too_large),
    ] {
    let result = @redact.preview_redaction(input(body), options([]), limits)
    assert_eq(result.diagnostics[0].code, code)
    assert_eq(result.points_removed, 0)
    assert_false(result.output_would_be_empty)
  }
  let mixed_namespace = preview(
    "<wpt xmlns=\"urn:unexpected\" lat=\"0\" lon=\"0\"/>",
    [],
  )
  assert_eq(
    mixed_namespace.diagnostics[0].code,
    @model.code_unsupported_namespace,
  )
  let invalid_encoding = @redact.preview_redaction(
    @model.GpxInput::new("invalid.gpx", Bytes::from_array([0xFF])),
    options([]),
    @model.default_input_limits(),
  )
  assert_true(invalid_encoding.diagnostics.length() > 0)
}

///|
test "preview accepts UTF-8 BOM and GPX 1.0 through the shared parser" {
  let bytes = Bytes::from_array([0xEF, 0xBB, 0xBF]) +
    @utf8.encode(
      "<gpx version=\"1.0\" creator=\"legacy\" xmlns=\"http://www.topografix.com/GPX/1/0\"><name>legacy name</name><rte><rtept lat=\"0\" lon=\"0\"/><rtept lat=\"1\" lon=\"1\"/></rte></gpx>",
    )
  let result = @redact.preview_redaction(
    @model.GpxInput::new("legacy.gpx", bytes),
    options([@model.MetadataName]),
    @model.default_input_limits(),
  )
  assert_eq(result.points_removed, 1)
  assert_eq(result.routes_removed, 0)
  assert_eq(result.metadata_fields_removed, 1)
  assert_eq(result.diagnostics.length(), 0)
}

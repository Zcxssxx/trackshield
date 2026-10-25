///|
test "valid geographic boundary coordinates are accepted" {
  let south_west = match @model.make_geo_point(-90.0, -180.0) {
    Ok(point) => point
    Err(error) => fail(error.to_string())
  }
  let north_east = match @model.make_geo_point(90.0, 180.0) {
    Ok(point) => point
    Err(error) => fail(error.to_string())
  }
  assert_eq(south_west.latitude, -90.0)
  assert_eq(north_east.longitude, 180.0)
}

///|
test "coordinates outside geographic ranges are rejected" {
  assert_true(is_invalid_point(@model.make_geo_point(-90.01, 0.0)))
  assert_true(is_invalid_point(@model.make_geo_point(90.01, 0.0)))
  assert_true(is_invalid_point(@model.make_geo_point(0.0, -180.01)))
  assert_true(is_invalid_point(@model.make_geo_point(0.0, 180.01)))
}

///|
test "NaN and infinite coordinates are rejected" {
  let nan = 0.0 / 0.0
  let infinity = 1.0 / 0.0
  assert_true(is_invalid_point(@model.make_geo_point(nan, 0.0)))
  assert_true(is_invalid_point(@model.make_geo_point(0.0, nan)))
  assert_true(is_invalid_point(@model.make_geo_point(infinity, 0.0)))
  assert_true(is_invalid_point(@model.make_geo_point(0.0, -infinity)))
}

///|
test "input resource limits require positive bounded values" {
  assert_true(is_invalid_limits(@model.make_input_limits(0, 1, 1, 1, 1, 1)))
  assert_true(is_invalid_limits(@model.make_input_limits(1, 0, 1, 1, 1, 1)))
  assert_true(is_invalid_limits(@model.make_input_limits(1, 1, 0, 1, 1, 1)))
  assert_true(is_invalid_limits(@model.make_input_limits(1, 1, 1, 0, 1, 1)))
  assert_true(is_invalid_limits(@model.make_input_limits(1, 1, 1, 1, 0, 1)))
  assert_true(is_invalid_limits(@model.make_input_limits(1, 1, 1, 1, 1, 0)))
  assert_true(is_invalid_limits(@model.make_input_limits(1, 1, 1, 1, 257, 1)))
  assert_true(
    is_invalid_limits(@model.make_input_limits(1, 1, 1, 1, 1, 2_000_001)),
  )
}

///|
test "input limits accept explicit bounded values" {
  let limits = match @model.make_input_limits(4096, 100, 8, 8192, 64, 1000) {
    Ok(value) => value
    Err(error) => fail(error.to_string())
  }
  assert_eq(limits.max_file_bytes, 4096)
  assert_eq(limits.max_xml_depth, 64)
  assert_eq(limits.max_xml_elements, 1000)
}

///|
test "GpxInput stores caller bytes and source label without file access" {
  let input = @model.GpxInput::new("fixture.gpx", Bytes::from_array([]))
  assert_eq(input.path, "fixture.gpx")
}

///|
test "audit options require a meaningful positive radius and support" {
  let nan = 0.0 / 0.0
  let infinity = 1.0 / 0.0
  assert_true(
    is_invalid_audit_options(@model.make_audit_options(0.0, 3, false)),
  )
  assert_true(
    is_invalid_audit_options(@model.make_audit_options(-1.0, 3, false)),
  )
  assert_true(
    is_invalid_audit_options(@model.make_audit_options(nan, 3, false)),
  )
  assert_true(
    is_invalid_audit_options(@model.make_audit_options(infinity, 3, false)),
  )
  assert_true(
    is_invalid_audit_options(@model.make_audit_options(20_100_000.0, 3, false)),
  )
  assert_true(
    is_invalid_audit_options(@model.make_audit_options(500.0, 1, false)),
  )
  assert_true(
    is_invalid_audit_options(@model.make_audit_options(500.0, 0, false)),
  )
}

///|
test "default options are documented and safe" {
  let limits = @model.default_input_limits()
  let audit = @model.default_audit_options()
  assert_true(limits.max_file_bytes > 0)
  assert_true(limits.max_total_bytes >= limits.max_file_bytes)
  assert_eq(limits.max_xml_depth, 128)
  assert_eq(audit.radius_m, 500.0)
  assert_eq(audit.min_distinct_files, 3)
  assert_eq(audit.include_coordinates, false)
}

///|
test "redaction options require a positive bounded radius" {
  let center = match @model.make_geo_point(0.0, 0.0) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  let nan = 0.0 / 0.0
  let infinity = 1.0 / 0.0
  assert_true(
    is_invalid_redaction_options(@model.make_redaction_options(center, 0.0, [])),
  )
  assert_true(
    is_invalid_redaction_options(
      @model.make_redaction_options(center, -1.0, []),
    ),
  )
  assert_true(
    is_invalid_redaction_options(@model.make_redaction_options(center, nan, [])),
  )
  assert_true(
    is_invalid_redaction_options(
      @model.make_redaction_options(center, infinity, []),
    ),
  )
  let categories : Array[@model.MetadataCategory] = [
    @model.TrackName,
    @model.PointTimestamp,
  ]
  let valid = match @model.make_redaction_options(center, 500.0, categories) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  assert_eq(valid.remove_metadata.length(), 2)
  categories.push(@model.Extensions)
  assert_eq(valid.remove_metadata.length(), 2)
}

///|
test "diagnostic rendering omits path and raw message values" {
  let diagnostic = @model.Diagnostic::new(
    "xml.doctype_forbidden",
    @model.Error,
    "C:/private/training/37.000,-122.000.gpx",
    "DOCTYPE is not supported",
  )
  let rendered = diagnostic.to_string()
  assert_eq(rendered, "xml.doctype_forbidden: DOCTYPE is not supported")
}

///|
fn is_invalid_point(
  result : Result[@model.GeoPoint, @model.Diagnostic],
) -> Bool {
  match result {
    Ok(_) => false
    Err(error) =>
      match error.severity {
        @model.Error => true
        _ => false
      }
  }
}

///|
fn is_invalid_limits(
  result : Result[@model.InputLimits, @model.Diagnostic],
) -> Bool {
  match result {
    Ok(_) => false
    Err(error) =>
      match error.severity {
        @model.Error => true
        _ => false
      }
  }
}

///|
fn is_invalid_audit_options(
  result : Result[@model.AuditOptions, @model.Diagnostic],
) -> Bool {
  match result {
    Ok(_) => false
    Err(error) =>
      match error.severity {
        @model.Error => true
        _ => false
      }
  }
}

///|
fn is_invalid_redaction_options(
  result : Result[@model.RedactionOptions, @model.Diagnostic],
) -> Bool {
  match result {
    Ok(_) => false
    Err(diagnostic) =>
      match diagnostic.severity {
        @model.Error => true
        _ => false
      }
  }
}
